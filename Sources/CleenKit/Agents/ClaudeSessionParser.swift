import Foundation

/// Reads a session's state from the end of its transcript (`<config>/projects/*/<id>.jsonl`).
///
/// Only the last few hundred kilobytes are read: the newest conversation event decides
/// the state, and the title and working directory are repeated often enough to be there.
public enum ClaudeSessionParser {
    /// How much of a transcript's tail is read.
    public static let tailBytes = 384 * 1024

    public static func session(id: String, tail: Data, updatedAt: Date) -> ClaudeSession? {
        var title: String?
        var directory: String?
        var state: ClaudeSession.State?
        var since: Date?
        var turnEnded = false

        let lines = tail.split(separator: UInt8(ascii: "\n"))
        let objects = lines.compactMap { try? JSONSerialization.jsonObject(with: Data($0)) as? [String: Any] }
        // Newest first: the first conversation event found decides the state.
        for object in objects.reversed() {
            if title == nil, object["type"] as? String == "ai-title", let value = object["aiTitle"] as? String, !value.isEmpty {
                title = value
            }
            if directory == nil, let cwd = object["cwd"] as? String { directory = cwd }
            if state == nil, isTurnEnd(object) { turnEnded = true }
            if state == nil, let found = Self.state(of: object) {
                state = found
                since = (object["timestamp"] as? String).flatMap(parseDate)
            }
            if state != nil, title != nil, directory != nil { break }
        }
        guard var state else { return nil }
        // Claude Code closed the turn after this event: whatever it looked like, nothing
        // is running anymore. An interruption, a question or an error keeps its own word.
        if turnEnded, isMidTurn(state) { state = .waiting }
        let name = title ?? directory.map { URL(filePath: $0).lastPathComponent } ?? String(id.prefix(8))
        return ClaudeSession(id: id, title: name, directory: directory, state: state, updatedAt: updatedAt, since: since ?? updatedAt, activity: ClaudeActivity.read(objects))
    }

    /// The state one conversation event leaves the session in; nil for bookkeeping lines
    /// (titles, attachments, API logs, local slash commands, system notes) and, unless
    /// asked for, for subagents' own events.
    static func state(of object: [String: Any], includingSidechains: Bool = false) -> ClaudeSession.State? {
        guard includingSidechains || object["isSidechain"] as? Bool != true,
              let type = object["type"] as? String,
              let message = object["message"] as? [String: Any]
        else { return nil }
        switch type {
        case "assistant":
            // "API Error: …", usage limits: written as an assistant line, but the model
            // never answered.
            if object["isApiErrorMessage"] as? Bool == true { return .failed }
            let content = message["content"] as? [[String: Any]] ?? []
            if let tool = content.last(where: { $0["type"] as? String == "tool_use" }) {
                switch tool["name"] as? String ?? "" {
                case "AskUserQuestion": return .asking
                case "ExitPlanMode": return .reviewingPlan
                case let name: return .running(tool: name)
                }
            }
            switch message["stop_reason"] as? String {
            case "end_turn", "stop_sequence", "max_tokens", "refusal": return .waiting
            // Streaming pieces of a turn still going (thinking, text) carry no stop reason
            // or "tool_use" before the call itself arrives.
            default: return .thinking
            }
        case "user":
            switch userEvent(object) {
            case .prompt, .toolResult: return .thinking
            case .interruption: return .interrupted
            case nil: return nil
            }
        default:
            return nil
        }
    }

    /// What a `user` line is. Many aren't the person writing: Claude Code also files
    /// slash commands, their output, hook context and compaction summaries as user lines.
    enum UserEvent {
        /// Something for the model to answer: a prompt, or a background task's
        /// `<task-notification>` that Claude Code hands the model (it resumes on it).
        case prompt
        case toolResult
        /// "[Request interrupted by user]", with or without "for tool use".
        case interruption
    }

    static func userEvent(_ object: [String: Any]) -> UserEvent? {
        guard object["type"] as? String == "user",
              let message = object["message"] as? [String: Any],
              // Hook and skill context, and "Compacted while idle" summaries.
              object["isMeta"] as? Bool != true,
              object["isCompactSummary"] as? Bool != true,
              // A `<task-notification>` Claude Code only records and never hands the model:
              // an agent whose report already came back as a message, shell tasks a
              // previous run left behind. Nothing answers it, so it starts no turn.
              object["queueTranscriptOnly"] as? Bool != true
        else { return nil }
        let text: String
        if let string = message["content"] as? String {
            text = string
        } else if let blocks = message["content"] as? [[String: Any]], !blocks.isEmpty {
            if blocks.contains(where: { $0["type"] as? String == "tool_result" }) { return .toolResult }
            // An image pasted alone is still a prompt.
            text = blocks.first { $0["type"] as? String == "text" }?["text"] as? String ?? ""
        } else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[Request interrupted by user") { return .interruption }
        if localCommandMarkers.contains(where: { trimmed.hasPrefix($0) }) { return nil }
        if isCompactCommand(trimmed) { return nil }
        return .prompt
    }

    /// A manual `/compact` goes in as the bare command, before its summary and its
    /// `<command-name>` echo. The model never answers it and no `turn_duration` follows,
    /// so read as a prompt it would leave the session thinking until it left the window.
    static func isCompactCommand(_ text: String) -> Bool {
        text.split(maxSplits: 1, whereSeparator: \.isWhitespace).first == "/compact"
    }

    /// How Claude Code wraps a slash command it runs itself (/clear, /model, /usage), a
    /// `!` shell command, and what they printed: the model doesn't answer them. A skill
    /// run as a slash command starts with `<command-message>` instead, and is a prompt.
    static let localCommandMarkers = [
        "<command-name>", "<local-command-stdout>", "<local-command-stderr>", "<local-command-caveat>",
        "<bash-input>", "<bash-stdout>", "<bash-stderr>",
    ]

    private static func isMidTurn(_ state: ClaudeSession.State) -> Bool {
        switch state {
        case .thinking, .running: true
        default: false
        }
    }

    /// Claude Code's own note that a turn finished ("Cooked for 2m 10s").
    static func isTurnEnd(_ object: [String: Any]) -> Bool {
        object["type"] as? String == "system" && object["subtype"] as? String == "turn_duration" && object["isSidechain"] as? Bool != true
    }

    private static func parseDate(_ text: String) -> Date? {
        try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
    }
}
