import Foundation

/// One thing Claude did in the current turn: a tool call, done or still running, with
/// what's worth showing about it (Droppy's progress list and detail card).
public struct ClaudeStep: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        /// A file read; its length once the read came back.
        case read(file: String, lines: Int?)
        case edit(file: String, added: Int, removed: Int)
        case write(file: String, lines: Int)
        /// A shell command, with the short description Claude gave it.
        case command(String, description: String?)
        case search(String)
        case web(String)
        /// A subagent, by its description.
        case agent(String)
        /// Any other tool, by name.
        case other(String)
    }

    /// The tool call's id.
    public let id: String
    public let kind: Kind
    public let isDone: Bool
    public let startedAt: Date?
    public let finishedAt: Date?

    public init(id: String, kind: Kind, isDone: Bool, startedAt: Date?, finishedAt: Date?) {
        self.id = id
        self.kind = kind
        self.isDone = isDone
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    /// The file's name for file steps.
    public var fileName: String? {
        switch kind {
        case .read(let file, _), .edit(let file, _, _), .write(let file, _): URL(filePath: file).lastPathComponent
        default: nil
        }
    }
}

/// What the current turn has done so far: its steps, oldest first, and the last thing
/// Claude said along the way.
public struct ClaudeActivity: Sendable, Equatable {
    public var steps: [ClaudeStep]
    /// Claude's latest sentence in this turn ("Tracing where the cart total goes stale").
    public var note: String?

    public static let empty = ClaudeActivity(steps: [], note: nil)

    /// How many steps are kept (the newest).
    public static let kept = 8

    /// Reads the turn from transcript lines in file order. A new prompt from the person
    /// starts a new turn; subagents' own events (sidechains) are left out.
    static func read(_ objects: [[String: Any]]) -> ClaudeActivity {
        var steps: [ClaudeStep] = []
        var index: [String: Int] = [:]
        var note: String?
        for object in objects {
            guard object["isSidechain"] as? Bool != true,
                  let type = object["type"] as? String,
                  let message = object["message"] as? [String: Any]
            else { continue }
            let time = (object["timestamp"] as? String).flatMap(parseDate)
            if type == "user" {
                // A plain prompt (not a tool result) begins a new turn.
                if message["content"] is String || (message["content"] as? [[String: Any]])?.contains(where: { $0["type"] as? String == "text" }) == true {
                    steps.removeAll()
                    index.removeAll()
                    note = nil
                    continue
                }
                for block in message["content"] as? [[String: Any]] ?? [] where block["type"] as? String == "tool_result" {
                    guard let id = block["tool_use_id"] as? String, let at = index[id] else { continue }
                    let step = steps[at]
                    let result = object["toolUseResult"] as? [String: Any]
                    steps[at] = ClaudeStep(id: id, kind: finished(step.kind, result: result), isDone: true, startedAt: step.startedAt, finishedAt: time)
                }
            } else if type == "assistant" {
                for block in message["content"] as? [[String: Any]] ?? [] {
                    switch block["type"] as? String {
                    case "tool_use":
                        guard let id = block["id"] as? String, index[id] == nil else { continue }
                        let kind = kind(of: block["name"] as? String ?? "", input: block["input"] as? [String: Any] ?? [:])
                        index[id] = steps.count
                        steps.append(ClaudeStep(id: id, kind: kind, isDone: false, startedAt: time, finishedAt: nil))
                    case "text":
                        if let text = block["text"] as? String, let sentence = firstSentence(text) { note = sentence }
                    default:
                        break
                    }
                }
            }
        }
        return ClaudeActivity(steps: Array(steps.suffix(kept)), note: note)
    }

    static func kind(of tool: String, input: [String: Any]) -> ClaudeStep.Kind {
        let file = input["file_path"] as? String ?? input["notebook_path"] as? String ?? ""
        switch tool {
        case "Read":
            return .read(file: file, lines: nil)
        case "Edit", "MultiEdit", "NotebookEdit":
            let old = input["old_string"] as? String ?? ""
            let new = input["new_string"] as? String ?? input["new_source"] as? String ?? ""
            return .edit(file: file, added: lineCount(new), removed: lineCount(old))
        case "Write":
            return .write(file: file, lines: lineCount(input["content"] as? String ?? ""))
        case "Bash":
            return .command(input["command"] as? String ?? "", description: input["description"] as? String)
        case "Grep", "Glob":
            return .search(input["pattern"] as? String ?? "")
        case "WebFetch":
            return .web((input["url"] as? String).flatMap { URL(string: $0)?.host() } ?? "")
        case "WebSearch":
            return .web(input["query"] as? String ?? "")
        case "Agent", "Task":
            return .agent(input["description"] as? String ?? "")
        default:
            return .other(tool)
        }
    }

    /// What the result adds: a read's length, an edit's exact diff.
    static func finished(_ kind: ClaudeStep.Kind, result: [String: Any]?) -> ClaudeStep.Kind {
        guard let result else { return kind }
        switch kind {
        case .read(let file, _):
            let lines = (result["file"] as? [String: Any])?["numLines"] as? Int
            return .read(file: file, lines: lines)
        case .edit(let file, let added, let removed):
            guard let hunks = result["structuredPatch"] as? [[String: Any]] else { return kind }
            let lines = hunks.flatMap { $0["lines"] as? [String] ?? [] }
            let plus = lines.filter { $0.hasPrefix("+") }.count
            let minus = lines.filter { $0.hasPrefix("-") }.count
            return plus + minus > 0 ? .edit(file: file, added: plus, removed: minus) : .edit(file: file, added: added, removed: removed)
        default:
            return kind
        }
    }

    static func lineCount(_ text: String) -> Int {
        text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    /// The first sentence of something Claude wrote, short enough for a card.
    static func firstSentence(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !line.isEmpty else { return nil }
        let cleaned = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        if let end = cleaned.firstIndex(where: { ".!?:".contains($0) }), cleaned.distance(from: cleaned.startIndex, to: end) > 12 {
            return String(cleaned[...end]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        }
        return cleaned.count > 120 ? String(cleaned.prefix(117)) + "…" : cleaned
    }

    static func parseDate(_ text: String) -> Date? {
        try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
    }
}
