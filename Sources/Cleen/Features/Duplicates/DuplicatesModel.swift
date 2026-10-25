import Foundation
import CleenKit
import Observation

@Observable
final class DuplicatesModel {
    private(set) var phase = ScanPhase.idle
    private(set) var progress = ""
    private(set) var groups: [DuplicateGroup] = []
    private(set) var isCleaning = false
    private(set) var report: CleanupReport?
    let roots = DuplicateFinder.defaultRoots()

    var selection = Set<URL>()

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
    }

    var wastedSize: Int64 { groups.reduce(0) { $0 + $1.wasted } }
    private var allFiles: [FoundFile] { groups.flatMap(\.files) }
    var selectedSize: Int64 { allFiles.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { allFiles.count { selection.contains($0.url) } }

    /// The copies about to go to the Lixo (the one kept in each group stays).
    var reviewItems: [DeletionReview.Item] {
        allFiles.filter { selection.contains($0.url) }.map { DeletionReview.Item(url: $0.url, size: $0.size) }
    }

    func startScan() {
        task?.cancel()
        task = Task { await performScan() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = groups.isEmpty ? .idle : .ready
    }

    private func performScan() async {
        phase = .scanning
        report = nil
        let finder = DuplicateFinder(roots: roots)
        let found = await offMain {
            finder.scan { path in
                Task { @MainActor [weak self] in self?.progress = Paths.abbreviate(URL(filePath: path)) }
            }
        }
        guard !Task.isCancelled else { return }
        groups = found
        selection = Set(found.flatMap { group in
            let keep = Self.keeper(in: group)
            return group.files.filter { $0.url != keep.url }.map(\.url)
        })
        phase = .ready
    }

    /// The copy kept by default: the oldest one that isn't sitting in Downloads, since
    /// a file in Documents or Pictures is more likely the one the person organized.
    static func keeper(in group: DuplicateGroup) -> FoundFile {
        let downloads = Paths.home.appending(path: "Downloads")
        return group.files.first { !Paths.isDescendant($0.url, of: downloads) } ?? group.files[0]
    }

    func toggle(_ file: FoundFile) {
        if selection.contains(file.url) { selection.remove(file.url) } else { selection.insert(file.url) }
    }

    /// Whether removing the current selection would leave a group with no copy at all.
    func removesEveryCopy(of group: DuplicateGroup) -> Bool {
        group.files.allSatisfy { selection.contains($0.url) }
    }

    var removesSomeGroupEntirely: Bool { groups.contains(where: removesEveryCopy) }

    func moveToTrash() async {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }
        let outcome = await cleanup.remove(allFiles.filter { selection.contains($0.url) }.map(\.request))
        let removed = Set(outcome.removed)
        groups = groups.compactMap { group in
            let remaining = group.files.filter { !removed.contains($0.url) }
            return remaining.count > 1 ? DuplicateGroup(id: group.id, files: remaining) : nil
        }
        selection.subtract(removed)
        report = CleanupReport(outcome)
    }
}
