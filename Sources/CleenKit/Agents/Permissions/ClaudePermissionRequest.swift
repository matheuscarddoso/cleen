import Foundation

/// What Claude Code hands a `PermissionRequest` hook on stdin: the tool it wants to use,
/// with what input, in which session.
/// https://code.claude.com/docs/en/hooks#permissionrequest-input
public struct ClaudePermissionRequest: Sendable, Equatable {
    public let sessionID: String
    public let directory: String?
    public let toolName: String
    public let toolInput: JSONValue
    /// The "don't ask again" rule Claude Code itself would offer, if it offers one.
    public let alwaysAllowRule: JSONValue?

    public init(sessionID: String, directory: String?, toolName: String, toolInput: JSONValue, alwaysAllowRule: JSONValue?) {
        self.sessionID = sessionID
        self.directory = directory
        self.toolName = toolName
        self.toolInput = toolInput
        self.alwaysAllowRule = alwaysAllowRule
    }

    /// `nil` for anything that isn't a permission request, or one the notch shouldn't
    /// answer (questions and plans are for reading in the terminal).
    public init?(json data: Data) {
        guard let root = try? JSONValue.parse(data),
              root["hook_event_name"]?.stringValue == ClaudeHookSettings.event,
              let tool = root["tool_name"]?.stringValue, !Self.terminalOnly.contains(tool)
        else { return nil }
        sessionID = root["session_id"]?.stringValue ?? ""
        directory = root["cwd"]?.stringValue
        toolName = tool
        toolInput = root["tool_input"] ?? .object([])
        alwaysAllowRule = root["permission_suggestions"]?.arrayValue?.first { suggestion in
            suggestion["type"]?.stringValue == "addRules" && suggestion["behavior"]?.stringValue == "allow"
                && suggestion["rules"]?.arrayValue?.isEmpty == false
        }
    }

    static let terminalOnly: Set = ["AskUserQuestion", "ExitPlanMode"]

    public var projectName: String? {
        directory.map { URL(filePath: $0).lastPathComponent }
    }

    /// The rule "Permitir sempre" would save, as Claude Code writes it: `Bash(npm test:*)`.
    public var alwaysAllowDescription: String? {
        guard let rules = alwaysAllowRule?["rules"]?.arrayValue else { return nil }
        let names = rules.compactMap { rule -> String? in
            guard let tool = rule["toolName"]?.stringValue else { return nil }
            guard let content = rule["ruleContent"]?.stringValue, !content.isEmpty else { return tool }
            return "\(tool)(\(content))"
        }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    public var summary: ClaudeToolSummary { ClaudeToolSummary(tool: toolName, input: toolInput, directory: directory) }
}

/// The answer that goes back to Claude Code on the hook's stdout.
/// https://code.claude.com/docs/en/hooks#permissionrequest-decision-control
public enum ClaudePermissionDecision: Sendable, Equatable {
    case allow
    /// Allows and saves Claude Code's own suggested rule, so it doesn't ask again.
    case allowAlways(rule: JSONValue)
    case deny

    public var output: Data {
        var decision: [JSONMember]
        switch self {
        case .allow:
            decision = [JSONMember("behavior", .string("allow"))]
        case .allowAlways(let rule):
            decision = [JSONMember("behavior", .string("allow")), JSONMember("updatedPermissions", .array([rule]))]
        case .deny:
            decision = [
                JSONMember("behavior", .string("deny")),
                JSONMember("message", .string("The user denied this from the notch.")),
                JSONMember("interrupt", .bool(false)),
            ]
        }
        let root = JSONValue.object([
            JSONMember("hookSpecificOutput", .object([
                JSONMember("hookEventName", .string(ClaudeHookSettings.event)),
                JSONMember("decision", .object(decision)),
            ])),
        ])
        return Data(root.printed(.init(indent: nil, trailingNewline: true)).utf8)
    }
}

/// A tool call in one line a person can judge at a glance: the command for Bash, the
/// file for an edit, the address for a fetch.
public struct ClaudeToolSummary: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case command, edit, write, read, fetch, search, agent
        case mcp(server: String, tool: String)
        case other(String)
    }

    public let kind: Kind
    /// The thing being acted on, in full; the view truncates it.
    public let subject: String
    /// Claude's own explanation, when it gives one (Bash's `description`).
    public let detail: String?
    /// Whether the subject is code (shown monospaced) rather than prose.
    public let isCode: Bool

    public init(tool: String, input: JSONValue, directory: String?) {
        func text(_ key: String) -> String? {
            input[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        func path(_ key: String) -> String? {
            text(key).map { Self.relative($0, to: directory) }
        }
        switch tool {
        case "Bash", "BashOutput", "PowerShell":
            self.init(kind: .command, subject: text("command") ?? tool, detail: text("description"), isCode: true)
        case "Edit", "MultiEdit":
            self.init(kind: .edit, subject: path("file_path") ?? tool, detail: nil, isCode: true)
        case "NotebookEdit":
            self.init(kind: .edit, subject: path("notebook_path") ?? tool, detail: nil, isCode: true)
        case "Write":
            self.init(kind: .write, subject: path("file_path") ?? tool, detail: nil, isCode: true)
        case "Read":
            self.init(kind: .read, subject: path("file_path") ?? tool, detail: nil, isCode: true)
        case "WebFetch":
            self.init(kind: .fetch, subject: text("url") ?? tool, detail: text("prompt"), isCode: true)
        case "WebSearch":
            self.init(kind: .search, subject: text("query") ?? tool, detail: nil, isCode: false)
        case "Glob", "Grep":
            self.init(kind: .search, subject: text("pattern") ?? tool, detail: path("path"), isCode: true)
        case "Task", "Agent":
            self.init(kind: .agent, subject: text("description") ?? tool, detail: text("subagent_type"), isCode: false)
        default:
            if tool.hasPrefix("mcp__") {
                let parts = tool.dropFirst(5).split(separator: "__", maxSplits: 1).map(String.init)
                let server = parts.first ?? tool
                let name = parts.count > 1 ? parts[1] : tool
                self.init(kind: .mcp(server: server, tool: name), subject: Self.firstText(in: input) ?? name, detail: nil, isCode: false)
            } else {
                self.init(kind: .other(tool), subject: Self.firstText(in: input) ?? tool, detail: nil, isCode: false)
            }
        }
    }

    init(kind: Kind, subject: String, detail: String?, isCode: Bool) {
        self.kind = kind
        self.subject = subject
        self.detail = detail
        self.isCode = isCode
    }

    /// A path inside the session's folder reads from there: `src/app.ts`.
    static func relative(_ path: String, to directory: String?) -> String {
        guard let directory, !directory.isEmpty else { return Paths.abbreviate(URL(filePath: path)) }
        let base = directory.hasSuffix("/") ? directory : directory + "/"
        if path.hasPrefix(base), path.count > base.count { return String(path.dropFirst(base.count)) }
        return Paths.abbreviate(URL(filePath: path))
    }

    private static func firstText(in input: JSONValue) -> String? {
        input.objectValue?.lazy.compactMap { $0.value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }.first
    }
}
