import Foundation
import Synchronization

/// The app's own record of what it was doing, kept across launches so a crash report can
/// carry the moments before it. The unified log can't serve: once the process is gone, only
/// an administrator can read its lines back.
///
/// Each line is one `write` straight to the file, unbuffered: a line written a moment
/// before a crash is already the kernel's and survives it. The file turns over at
/// `maxBytes`, the previous one kept beside it as `.1`.
public final class BreadcrumbLog: Sendable {
    public enum Level: String, Sendable {
        case info = "I"
        case warning = "W"
        case error = "E"
    }

    public let url: URL
    /// "2026-11-21T13:51:45.882Z": UTC, said so, to the millisecond.
    private static let stamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private let maxBytes: UInt64
    private let handle = Mutex<FileHandle?>(nil)

    public init(url: URL, maxBytes: UInt64 = 256 * 1024) {
        self.url = url
        self.maxBytes = maxBytes
    }

    private var previousURL: URL { url.appendingPathExtension("1") }

    public func record(_ level: Level, _ category: String, _ message: String, at date: Date = .now) {
        // One line each, short enough for the server's limit on a line (600).
        let flat = String(message.replacingOccurrences(of: "\n", with: " ").prefix(480))
        let line = "\(date.formatted(Self.stamp)) \(level.rawValue) [\(category)] \(flat)\n"
        handle.withLock { current in
            if current == nil { current = open() }
            guard let file = current else { return }
            if (try? file.offset()) ?? 0 >= maxBytes {
                try? file.close()
                try? FileManager.default.removeItem(at: previousURL)
                try? FileManager.default.moveItem(at: url, to: previousURL)
                current = open()
            }
            try? current?.write(contentsOf: Data(line.utf8))
        }
    }

    /// The last `limit` lines written at or before `date` (all of them when nil), oldest
    /// first, from this file and the one before it.
    public func lines(before date: Date? = nil, limit: Int = 200) -> [String] {
        let text = [previousURL, url].compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if let date {
            let cutoff = date.addingTimeInterval(1)
            lines = lines.filter { line in
                guard let stamp = line.split(separator: " ", maxSplits: 1).first,
                      let written = try? Date(String(stamp), strategy: Self.stamp)
                else { return false }
                return written <= cutoff
            }
        }
        return Array(lines.suffix(limit))
    }

    private func open() -> FileHandle? {
        let manager = FileManager.default
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: url.path(percentEncoded: false)) {
            manager.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        }
        guard let file = try? FileHandle(forWritingTo: url) else { return nil }
        _ = try? file.seekToEnd()
        return file
    }
}
