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

    /// Newest first. Reads only transcripts modified inside the window; blocking, so
    /// call it off the main thread.
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
                      now.timeIntervalSince(modified) <= window,
                      let tail = Self.tail(of: file, bytes: ClaudeSessionParser.tailBytes),
                      let session = ClaudeSessionParser.session(id: file.deletingPathExtension().lastPathComponent, tail: tail, updatedAt: modified)
                else { continue }
                sessions.append(session)
            }
        }
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
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
