import Foundation

public enum FileSizer {
    /// Bytes allocated on disk by `url` and everything below it. Hard-linked files count
    /// once, so a pnpm store or a Time Machine-style tree isn't inflated.
    /// Returns early (with a partial total) if the surrounding task is cancelled.
    public static func allocatedSize(of url: URL) -> Int64 {
        var total: Int64 = 0
        var seenLinks = Set<FileIdentity>()
        var visited = 0

        FileWalker.walk(url) { entry in
            visited += 1
            if visited % 4096 == 0, Task.isCancelled { return .stop }

            switch entry.kind {
            case .file, .symlink:
                if entry.linkCount > 1, let identity = entry.inode {
                    guard seenLinks.insert(identity).inserted else { return .proceed }
                }
                total += entry.allocatedSize
            case .directory:
                total += entry.allocatedSize
            case .directoryEnd, .unreadable, .ignored:
                break
            }
            return .proceed
        }
        return total
    }

    /// Whether anything exists at `url`, without following a trailing symlink.
    public static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path(percentEncoded: false), &info) == 0
    }
}
