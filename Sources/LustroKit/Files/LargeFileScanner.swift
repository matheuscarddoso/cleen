import Foundation

public struct LargeFileScanner: Sendable {
    let root: URL
    let minimumSize: Int64
    let home: URL

    public init(root: URL = Paths.home, minimumSize: Int64 = 50_000_000, home: URL = Paths.home) {
        self.root = root
        self.minimumSize = minimumSize
        self.home = home
    }

    /// Files at or above `minimumSize`, largest first. Uses allocated size, so iCloud
    /// placeholders (which free nothing when removed) don't show up.
    public func scan(progress: @Sendable (String) -> Void = { _ in }) -> [FoundFile] {
        var files: [FoundFile] = []
        var visited = 0
        let isHome = root.standardizedFileURL == home.standardizedFileURL

        FileWalker.walk(root) { entry in
            visited += 1
            if visited % 2048 == 0 {
                if Task.isCancelled { return .stop }
                progress(entry.path)
            }
            switch entry.kind {
            case .directory where entry.level > 0:
                return ScanExclusions.shouldSkip(folderName: entry.name, level: entry.level, home: isHome)
                    ? .skipChildren : .proceed
            case .file:
                let size = entry.allocatedSize
                guard size >= minimumSize, !entry.isDataless else { return .proceed }
                let url = URL(filePath: entry.path)
                files.append(FoundFile(
                    url: url,
                    size: size,
                    modified: entry.modified,
                    accessed: entry.accessed,
                    kind: FileKind(fileExtension: url.pathExtension)
                ))
                return .proceed
            default:
                return .proceed
            }
        }
        return files.sorted { $0.size > $1.size }
    }
}
