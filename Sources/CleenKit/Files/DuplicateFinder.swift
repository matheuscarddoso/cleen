import CryptoKit
import Foundation

public struct DuplicateFinder: Sendable {
    let roots: [URL]
    let minimumSize: Int64

    public static func defaultRoots(home: URL = Paths.home) -> [URL] {
        ["Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music"]
            .map { home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    public init(roots: [URL], minimumSize: Int64 = 1_000_000) {
        self.roots = roots
        self.minimumSize = minimumSize
    }

    /// Byte-identical files, compared in three passes so most files are never read:
    /// same size → same first 64 KB → same SHA-256 of the whole file.
    public func scan(progress: @Sendable (String) -> Void = { _ in }) -> [DuplicateGroup] {
        let candidates = collect(progress: progress)
        var groups: [DuplicateGroup] = []

        for sameSize in Dictionary(grouping: candidates, by: \.size).values where sameSize.count > 1 {
            if Task.isCancelled { break }
            let byHead = Dictionary(grouping: sameSize) { Self.digest($0.url, limit: 65_536) }
            for (head, sameHead) in byHead where head != nil && sameHead.count > 1 {
                progress(sameHead[0].url.path(percentEncoded: false))
                let byContent = sameHead[0].size <= 65_536
                    ? [head: sameHead]
                    : Dictionary(grouping: sameHead) { Self.digest($0.url, limit: nil) }
                for (hash, identical) in byContent where hash != nil && identical.count > 1 {
                    groups.append(DuplicateGroup(
                        id: hash ?? UUID().uuidString,
                        files: identical.sorted { $0.modified < $1.modified }
                    ))
                }
            }
        }
        return groups.sorted { $0.wasted > $1.wasted }
    }

    private func collect(progress: @Sendable (String) -> Void) -> [FoundFile] {
        var files: [FoundFile] = []
        var seen = Set<FileIdentity>()
        var visited = 0
        for root in roots {
            FileWalker.walk(root) { entry in
                visited += 1
                if visited % 2048 == 0 {
                    if Task.isCancelled { return .stop }
                    progress(entry.path)
                }
                switch entry.kind {
                case .directory where entry.level > 0:
                    return ScanExclusions.shouldSkip(folderName: entry.name, level: entry.level, home: false)
                        || entry.name.hasPrefix(".") ? .skipChildren : .proceed
                case .file:
                    // Reading an evicted iCloud file would download it; hard links to the
                    // same inode are one file, not two.
                    guard entry.logicalSize >= minimumSize, !entry.isDataless,
                          !entry.name.hasPrefix("."),
                          let identity = entry.inode, seen.insert(identity).inserted
                    else { return .proceed }
                    let url = URL(filePath: entry.path)
                    files.append(FoundFile(
                        url: url,
                        size: entry.logicalSize,
                        modified: entry.modified,
                        accessed: entry.accessed,
                        kind: FileKind(fileExtension: url.pathExtension)
                    ))
                    return .proceed
                default:
                    return .proceed
                }
            }
        }
        return files
    }

    /// SHA-256 of the first `limit` bytes, or the whole file when `limit` is nil.
    static func digest(_ url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? .max
        let chunk = 1 << 20
        while remaining > 0 {
            guard let data = try? handle.read(upToCount: min(chunk, remaining)), !data.isEmpty else { break }
            hasher.update(data: data)
            remaining -= data.count
            if Task.isCancelled { return nil }
        }
        return hasher.finalize().map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
    }
}
