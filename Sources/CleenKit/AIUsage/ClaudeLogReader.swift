import Foundation
import Synchronization

/// Reads token usage out of Claude Code's transcripts (`~/.claude/projects/**/*.jsonl`).
///
/// Those files add up to gigabytes, so reading is incremental: each file is parsed once,
/// and afterwards only the bytes appended since (transcripts only ever grow). The parsed
/// state is saved to a small cache file, so a relaunch doesn't start over.
public final class ClaudeLogReader: Sendable {
    struct FileState: Codable {
        var offset: UInt64
        var modified: Date
        var entries: [UsageEntry]
    }

    private let root: URL
    private let cacheURL: URL?
    private let files: Mutex<[String: FileState]>
    /// Older entries don't matter for a 30-day view; skipping them keeps parsing cheap.
    private let horizon: TimeInterval

    public init(
        root: URL = Paths.home.appending(path: ".claude/projects"),
        cacheURL: URL? = ClaudeLogReader.defaultCacheURL,
        horizon: TimeInterval = 35 * 86_400
    ) {
        self.root = root
        self.cacheURL = cacheURL
        self.horizon = horizon
        let saved = cacheURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([String: FileState].self, from: $0) }
        files = Mutex(saved ?? [:])
    }

    public static var defaultCacheURL: URL? {
        URL.cachesDirectory.appending(path: "app.cleen.Cleen/claude-usage-v1.json")
    }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: root.path(percentEncoded: false))
    }

    /// Every usage entry in the horizon, deduplicated, oldest first.
    public func read() -> [UsageEntry] {
        let cutoff = Date.now.addingTimeInterval(-horizon)
        let paths = transcriptPaths(modifiedAfter: cutoff)

        let snapshot = files.withLock { $0 }
        var updated: [String: FileState] = [:]
        for (path, modified) in paths {
            if Task.isCancelled { break }
            var state = snapshot[path] ?? FileState(offset: 0, modified: .distantPast, entries: [])
            if state.modified != modified {
                let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64) ?? 0
                // A shorter file means it was rewritten; start over.
                if size < state.offset { state = FileState(offset: 0, modified: .distantPast, entries: []) }
                if let (newEntries, end) = Self.parse(path: path, from: state.offset) {
                    state.entries += newEntries.filter { $0.timestamp >= cutoff }
                    state.offset = end
                }
                state.modified = modified
            }
            state.entries.removeAll { $0.timestamp < cutoff }
            updated[path] = state
        }
        files.withLock { $0 = updated }
        save(updated)

        var seen = Set<String>()
        return updated.values.flatMap(\.entries)
            .sorted { $0.timestamp < $1.timestamp }
            .filter { seen.insert($0.key).inserted }
    }

    private func transcriptPaths(modifiedAfter cutoff: Date) -> [(String, Date)] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var result: [(String, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modified >= cutoff
            else { continue }
            result.append((url.path(percentEncoded: false), modified))
        }
        return result
    }

    private func save(_ state: [String: FileState]) {
        guard let cacheURL, let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }

    /// Parses complete lines from `offset` on; returns the entries and where the last
    /// complete line ended (a line still being written is left for next time).
    static func parse(path: String, from offset: UInt64) -> ([UsageEntry], UInt64)? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        do { try handle.seek(toOffset: offset) } catch { return nil }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return ([], offset) }
        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return ([], offset) }

        var entries: [UsageEntry] = []
        let marker = Array("\"output_tokens\"".utf8)
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            let end = data.distance(from: data.startIndex, to: lastNewline)
            var lineStart = 0
            while lineStart < end {
                let remaining = end - lineStart
                let lineEnd = memchr(base + lineStart, 0x0A, remaining).map { base.distance(to: UnsafeRawPointer($0)) } ?? end
                let length = lineEnd - lineStart
                // Most lines (tool output, user turns) carry no usage; skip them unparsed.
                if length > 0, memmem(base + lineStart, length, marker, marker.count) != nil {
                    let line = Data(bytes: base + lineStart, count: length)
                    if let entry = entry(from: line) { entries.append(entry) }
                }
                lineStart = lineEnd + 1
            }
        }
        return (entries, offset + UInt64(data.distance(from: data.startIndex, to: lastNewline)) + 1)
    }

    static func entry(from line: Data) -> UsageEntry? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = message["model"] as? String, model != "<synthetic>",
              let stamp = object["timestamp"] as? String,
              let timestamp = (try? Date(stamp, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)))
                ?? (try? Date(stamp, strategy: .iso8601))
        else { return nil }
        func int(_ key: String) -> Int { (usage[key] as? NSNumber)?.intValue ?? 0 }
        let id = message["id"] as? String ?? ""
        let request = object["requestId"] as? String ?? (object["uuid"] as? String ?? "")
        return UsageEntry(
            timestamp: timestamp,
            model: model,
            input: int("input_tokens"),
            output: int("output_tokens"),
            cacheWrite: int("cache_creation_input_tokens"),
            cacheRead: int("cache_read_input_tokens"),
            key: id.isEmpty ? request : "\(id)|\(request)"
        )
    }
}
