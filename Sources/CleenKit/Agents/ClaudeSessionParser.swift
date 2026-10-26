import Foundation

/// Reads a session's state from the end of its transcript (`~/.claude/projects/*/<id>.jsonl`).
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

        let lines = tail.split(separator: UInt8(ascii: "\n"))
        let objects = lines.compactMap { try? JSONSerialization.jsonObject(with: Data($0)) as? [String: Any] }
        // Newest first: the first conversation event found decides the state.
        for object in objects.reversed() {
            if title == nil, object["type"] as? String == "ai-title", let value = object["aiTitle"] as? String, !value.isEmpty {
                title = value
            }
            if directory == nil, let cwd = object["cwd"] as? String { directory = cwd }
            if state == nil, let found = Self.state(of: object) {
                state = found
                since = (object["timestamp"] as? String).flatMap(parseDate)
            }
            if state != nil, title != nil, directory != nil { break }
        }
        guard let state else { return nil }
        let name = title ?? directory.map { URL(filePath: $0).lastPathComponent } ?? String(id.prefix(8))
        return ClaudeSession(id: id, title: name, directory: directory, state: state, updatedAt: updatedAt, since: since ?? updatedAt, activity: ClaudeActivity.read(objects))
    }

    /// The state one conversation event leaves the session in; nil for bookkeeping lines
    /// (titles, attachments, API logs) and, unless asked for, for subagents' own events.
    static func state(of object: [String: Any], includingSidechains: Bool = false) -> ClaudeSession.State? {
        guard includingSidechains || object["isSidechain"] as? Bool != true,
              let type = object["type"] as? String,
              let message = object["message"] as? [String: Any]
        else { return nil }
        switch type {
        case "assistant":
            let content = message["content"] as? [[String: Any]] ?? []
            if let tool = content.last(where: { $0["type"] as? String == "tool_use" }) {
                return .running(tool: tool["name"] as? String ?? "")
            }
            switch message["stop_reason"] as? String {
            case "end_turn", "stop_sequence", "max_tokens", "refusal": return .waiting
            // Streaming pieces of a turn still going (thinking, text) carry no stop reason
            // or "tool_use" before the call itself arrives.
            default: return .thinking
            }
        case "user":
            // A tool result or a new prompt: the model is up.
            return .thinking
        default:
            return nil
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
    }
}
