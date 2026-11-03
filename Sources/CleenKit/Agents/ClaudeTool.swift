import Foundation

/// What a running tool call amounts to, so the app can say it in a few words
/// ("Lendo arquivos") instead of showing Claude Code's internal tool names.
public enum ClaudeTool: Sendable, Equatable {
    case command
    case reading
    case editing
    case searching
    case web
    /// A subagent in the foreground: the session waits on it.
    case agent
    case workflow
    case skill
    /// ToolSearch, fetching the schemas of deferred tools.
    case loadingTools
    /// A tool from an MCP server, by the server's readable name ("Notion").
    case mcp(server: String)
    /// Any other tool, by name; empty when the transcript didn't say.
    case other(String)

    public init(name: String) {
        switch name {
        case "Bash", "BashOutput", "PowerShell": self = .command
        case "Read": self = .reading
        case "Edit", "MultiEdit", "Write", "NotebookEdit": self = .editing
        case "Grep", "Glob", "LSP": self = .searching
        case "WebFetch", "WebSearch": self = .web
        case "Agent", "Task": self = .agent
        case "Workflow": self = .workflow
        case "Skill": self = .skill
        case "ToolSearch": self = .loadingTools
        default:
            if let server = Self.mcpServer(of: name) {
                self = .mcp(server: server)
            } else {
                self = .other(name)
            }
        }
    }

    /// `mcp__<server>__<tool>` → the server, readable: Claude Code prefixes the
    /// claude.ai connectors (`claude_ai_Notion`) and plugin servers
    /// (`plugin_figma_figma`), and neither prefix means anything to the person.
    static func mcpServer(of tool: String) -> String? {
        let parts = tool.components(separatedBy: "__")
        guard parts.count >= 3, parts[0] == "mcp", !parts[1].isEmpty else { return nil }
        var server = parts[1]
        if server.hasPrefix("claude_ai_") {
            server.removeFirst("claude_ai_".count)
        } else if server.hasPrefix("plugin_") {
            server.removeFirst("plugin_".count)
            // plugin_<plugin>_<server>: the server's own name is what's left.
            if let underscore = server.firstIndex(of: "_"), server.index(after: underscore) < server.endIndex {
                server = String(server[server.index(after: underscore)...])
            }
        }
        let words = server.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
        guard let first = words.first else { return nil }
        return first.uppercased() + words.dropFirst()
    }
}
