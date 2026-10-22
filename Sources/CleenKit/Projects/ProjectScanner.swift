import Foundation

public struct ProjectScanner: Sendable {
    let roots: [URL]
    let maxDepth: Int

    /// Folders where people usually keep code. Only the ones that exist are scanned.
    public static func defaultRoots(home: URL = Paths.home) -> [URL] {
        ["Projects", "Developer", "Code", "code", "dev", "src", "Sites", "workspace", "GitHub", "repos"]
            .map { home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    public init(roots: [URL], maxDepth: Int = 8) {
        self.roots = roots
        self.maxDepth = maxDepth
    }

    public func scan(progress: @escaping @Sendable (String) -> Void = { _ in }) async -> [CodeProject] {
        let found = await BlockingIO.run { [self] in self.locateArtifacts(progress: progress) }
        let sized = await measure(found)

        let byProject = Dictionary(grouping: sized) { $0.url.deletingLastPathComponent().standardizedFileURL }
        return byProject.map { root, artifacts in
            CodeProject(
                url: root,
                name: root.lastPathComponent,
                lastActivity: Self.lastActivity(of: root, ignoring: Set(artifacts.map(\.url.lastPathComponent))),
                artifacts: artifacts.sorted { $0.size > $1.size }
            )
        }
        .filter { $0.totalSize > 0 }
        .sorted { $0.totalSize > $1.totalSize }
    }

    // MARK: - Discovery

    struct Found: Sendable {
        let url: URL
        let kind: ArtifactKind
    }

    func locateArtifacts(progress: @Sendable (String) -> Void) -> [Found] {
        var found: [Found] = []
        let manager = FileManager.default
        let exists: (URL) -> Bool = { manager.fileExists(atPath: $0.path(percentEncoded: false)) }

        for root in roots {
            var visited = 0
            FileWalker.walk(root) { entry in
                guard entry.kind == .directory else { return .proceed }
                visited += 1
                if visited % 512 == 0 {
                    if Task.isCancelled { return .stop }
                    progress(entry.path)
                }
                guard entry.level > 0 else { return .proceed }
                guard entry.level <= maxDepth else { return .skipChildren }

                let name = entry.name
                let url = URL(filePath: entry.path, directoryHint: .isDirectory)
                if let kind = ArtifactKind.match(folderName: name, parent: url.deletingLastPathComponent(), fileExists: exists) {
                    found.append(Found(url: url, kind: kind))
                    return .skipChildren
                }
                // Version control internals, app bundles and stray dot-folders never
                // contain projects of their own.
                if name.hasPrefix(".") || name.hasSuffix(".app") || name.hasSuffix(".xcodeproj")
                    || name.hasSuffix(".xcworkspace") {
                    return .skipChildren
                }
                return .proceed
            }
        }
        return found
    }

    func measure(_ found: [Found]) async -> [ProjectArtifact] {
        await withTaskGroup(of: ProjectArtifact.self) { group in
            var iterator = found.makeIterator()
            let width = DiskParallelism.width
            var artifacts: [ProjectArtifact] = []

            func addNext() -> Bool {
                guard let next = iterator.next() else { return false }
                group.addTask {
                    ProjectArtifact(url: next.url, kind: next.kind, size: await BlockingIO.run { FileSizer.allocatedSize(of: next.url) })
                }
                return true
            }

            for _ in 0..<width where !addNext() { break }
            for await artifact in group {
                artifacts.append(artifact)
                _ = addNext()
            }
            return artifacts
        }
    }

    // MARK: - Activity

    static func lastActivity(of project: URL, ignoring artifactNames: Set<String>) -> Date {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        var newest = Date.distantPast

        let gitIndex = project.appending(path: ".git/index")
        if let date = try? gitIndex.resourceValues(forKeys: keys).contentModificationDate {
            newest = date
        }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: project, includingPropertiesForKeys: Array(keys), options: []
        )) ?? []
        for child in children {
            let name = child.lastPathComponent
            guard !artifactNames.contains(name), name != ".DS_Store", name != ".git" else { continue }
            if let date = try? child.resourceValues(forKeys: keys).contentModificationDate, date > newest {
                newest = date
            }
        }
        return newest == .distantPast ? .now : newest
    }
}
