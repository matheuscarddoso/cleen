import Foundation

public struct JunkScanner: Sendable {
    let home: URL
    let catalog: [JunkCategory]
    let runningBundleIDs: Set<String>
    /// Re-roots absolute sources (`/Applications`) for tests; nil means the real disk.
    let systemRoot: URL?

    public init(
        home: URL = Paths.home,
        catalog: [JunkCategory] = JunkCatalog.all,
        runningBundleIDs: Set<String> = [],
        systemRoot: URL? = nil
    ) {
        self.home = home
        self.catalog = catalog
        self.runningBundleIDs = runningBundleIDs
        self.systemRoot = systemRoot
    }

    /// Finds every candidate in the catalog and sizes it. Categories with nothing to
    /// clean are omitted. `progress` receives the title of the category being scanned.
    public func scan(progress: @Sendable (String) -> Void = { _ in }) async -> [JunkCategoryResult] {
        let claimed = claimedPaths()
        var results: [JunkCategoryResult] = []
        for category in catalog {
            if Task.isCancelled { break }
            progress(category.title)
            let found = category.sources.flatMap { self.candidates(for: $0, in: category, claimed: claimed) }
            let items = await Self.measure(found, category: category)
                .sorted { $0.size > $1.size }
            if !items.isEmpty {
                results.append(JunkCategoryResult(category: category, items: items))
            }
        }
        return results
    }

    // MARK: - Candidates

    struct Candidate: Sendable {
        let url: URL
        let name: String
        let note: String?
    }

    /// Every folder some source owns. A generic `.contents` source must step around these.
    func claimedPaths() -> Set<String> {
        Set(catalog.flatMap(\.sources).map { normalized(resolve($0.path)) })
    }

    func candidates(for source: JunkSource, in category: JunkCategory, claimed: Set<String>) -> [Candidate] {
        let root = resolve(source.path)
        let ownerRunning = source.bundleID.map(runningBundleIDs.contains) ?? false
        let runningNote = ownerRunning ? "O app está aberto" : nil

        switch source.shape {
        case .whole:
            guard FileSizer.exists(root) else { return [] }
            return [Candidate(url: root, name: source.label ?? root.lastPathComponent, note: runningNote)]

        case .files(let extensions):
            return children(of: root).compactMap { child in
                guard extensions.contains(child.pathExtension.lowercased()),
                      (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                else { return nil }
                return Candidate(url: child, name: child.lastPathComponent, note: nil)
            }

        case .contents:
            return expand(root, category: category, claimed: claimed, inheritedNote: runningNote)
        }
    }

    /// Lists the children of `folder` as candidates, stepping into any child that
    /// contains a folder claimed by another source so it's never counted twice.
    private func expand(_ folder: URL, category: JunkCategory, claimed: Set<String>, inheritedNote: String?) -> [Candidate] {
        children(of: folder).flatMap { child -> [Candidate] in
            let name = child.lastPathComponent
            guard !category.excludedNames.contains(name) else { return [] }
            let path = normalized(child)
            if claimed.contains(path) { return [] }
            if claimed.contains(where: { $0.hasPrefix(path + "/") }) {
                return expand(child, category: category, claimed: claimed, inheritedNote: inheritedNote)
            }
            let note = inheritedNote ?? (runningBundleIDs.contains(name) ? "O app está aberto" : nil)
            return [Candidate(url: child, name: name, note: note)]
        }
    }

    private func children(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        )) ?? []
    }

    private func resolve(_ path: String) -> URL {
        if !path.hasPrefix("~"), let systemRoot { return systemRoot.appending(path: path) }
        return Paths.expand(path, home: home)
    }

    private func normalized(_ url: URL) -> String {
        url.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
    }

    // MARK: - Sizing

    /// Sizes candidates in parallel; trees like DerivedData are big enough to make the
    /// difference between a scan that feels instant and one that doesn't.
    static func measure(_ candidates: [Candidate], category: JunkCategory) async -> [JunkItem] {
        await withTaskGroup(of: JunkItem?.self) { group in
            var iterator = candidates.makeIterator()
            let width = DiskParallelism.width
            var items: [JunkItem] = []

            func addNext() -> Bool {
                guard let candidate = iterator.next() else { return false }
                group.addTask {
                    let size = FileSizer.allocatedSize(of: candidate.url)
                    guard size > 0 else { return nil }
                    return JunkItem(
                        url: candidate.url,
                        name: candidate.name,
                        size: size,
                        categoryID: category.id,
                        removal: category.removal,
                        selectedByDefault: category.selectedByDefault && candidate.note == nil,
                        note: candidate.note
                    )
                }
                return true
            }

            for _ in 0..<width where !addNext() { break }
            for await item in group {
                if let item { items.append(item) }
                _ = addNext()
            }
            return items
        }
    }
}
