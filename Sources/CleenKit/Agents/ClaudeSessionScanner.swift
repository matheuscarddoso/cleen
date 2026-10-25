import Foundation

/// Finds the Claude Code sessions that moved recently and reads their state.
public struct ClaudeSessionScanner: Sendable {
    public let root: URL
    /// Sessions untouched for longer than this aren't shown.
    public let window: TimeInterval

    public init(root: URL = Paths.home.appending(path: ".claude/projects"), window: TimeInterval = 30 * 60) {
        self.root = root
        self.window = window
    }

    /// A background agent whose transcript hasn't moved for this long is taken as gone,
    /// even if its metadata never got to say it finished.
    public static let agentActivity: TimeInterval = 10 * 60

    /// Newest first. Reads only transcripts modified inside the window (or whose
    /// background agents are still at work); blocking, so call it off the main thread.
    public func scan(now: Date = .now) -> [ClaudeSession] {
        let files = FileManager.default
        guard let projects = try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }
        var sessions: [ClaudeSession] = []
        for project in projects {
            // A folder's date moves when a transcript is created in it, not appended to,
            // so every folder is listed; listing is cheap next to reading.
            guard let transcripts = try? files.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for file in transcripts where file.pathExtension == "jsonl" {
                guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      // A workflow can run for hours while its session's own file sits still.
                      now.timeIntervalSince(modified) <= max(window, 24 * 3600)
                else { continue }
                let id = file.deletingPathExtension().lastPathComponent
                let agents = Self.activeAgents(in: project.appending(path: id).appending(path: "subagents"), now: now)
                let updated = max(modified, agents.latest ?? .distantPast)
                guard now.timeIntervalSince(updated) <= window,
                      let tail = Self.tail(of: file, bytes: ClaudeSessionParser.tailBytes),
                      let session = ClaudeSessionParser.session(id: id, tail: tail, updatedAt: updated)
                else { continue }
                sessions.append(agents.count > 0 ? session.delegating(agents.count) : session)
            }
        }
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The background agents still working for a session: each writes
    /// `subagents/agent-<id>.jsonl` next to a `.meta.json` that says `"finished": true`
    /// once it's done. `latest` is when any of them last wrote, finished or not.
    static func activeAgents(in folder: URL, now: Date) -> (count: Int, latest: Date?) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return (0, nil) }
        var count = 0
        var latest: Date?
        for file in files where file.pathExtension == "jsonl" {
            guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { continue }
            latest = max(latest ?? modified, modified)
            guard now.timeIntervalSince(modified) <= agentActivity else { continue }
            // Older Claude Code never writes `finished`: then the agent's own last word says it.
            let meta = file.deletingPathExtension().appendingPathExtension("meta.json")
            if !isFinished(meta), !endedItsTurn(file) { count += 1 }
        }
        return (count, latest)
    }

    static func endedItsTurn(_ transcript: URL) -> Bool {
        guard let tail = tail(of: transcript, bytes: 64 * 1024) else { return false }
        for line in tail.split(separator: UInt8(ascii: "\n")).reversed() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let state = ClaudeSessionParser.state(of: object, includingSidechains: true)
            else { continue }
            return state == .waiting
        }
        return false
    }

    static func isFinished(_ meta: URL) -> Bool {
        guard let data = try? Data(contentsOf: meta),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["finished"] as? Bool == true
    }

    static func tail(of url: URL, bytes: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let start = size > UInt64(bytes) ? size - UInt64(bytes) : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { return nil }
        // Starting mid-line, the first line is a fragment: drop it.
        if start > 0, let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
            data = data.subdata(in: data.index(after: newline)..<data.endIndex)
        }
        return data
    }
}
