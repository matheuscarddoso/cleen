import Foundation
import CleenKit
import Observation

@Observable
final class OrphansModel {
    private(set) var phase = ScanPhase.idle
    private(set) var groups: [OrphanGroup] = []
    private(set) var isCleaning = false
    private(set) var report: CleanupReport?

    var selection = Set<URL>()

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
    }

    var totalSize: Int64 { groups.reduce(0) { $0 + $1.totalSize } }
    private var allItems: [Leftover] { groups.flatMap(\.items) }
    var selectedSize: Int64 { allItems.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { allItems.count { selection.contains($0.url) } }

    /// What's about to go to the Lixo, each with what it was.
    var reviewItems: [DeletionReview.Item] {
        allItems.filter { selection.contains($0.url) }.map { DeletionReview.Item(url: $0.url, size: $0.size, detail: $0.place.title) }
    }

    func scan() async {
        task?.cancel()
        let task = Task { await performScan() }
        self.task = task
        await task.value
    }

    func startScan() {
        task?.cancel()
        task = Task { await performScan() }
    }

    private func performScan() async {
        phase = .scanning
        report = nil
        let installed = await offMain {
            Set(AppCatalog.bundles().compactMap { Bundle(url: $0)?.bundleIdentifier })
        }
        let finder = OrphanFinder(installedBundleIDs: installed)
        let found = await offMain { finder.scan() }
        guard !Task.isCancelled else { return }
        groups = found
        selection = Set(found.flatMap(\.items).map(\.url))
        phase = .ready
    }

    func state(of group: OrphanGroup) -> CheckState {
        CheckState(selected: group.items.count { selection.contains($0.url) }, of: group.items.count)
    }

    func toggle(_ item: Leftover) {
        if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
    }

    func toggle(_ group: OrphanGroup) {
        let urls = group.items.map(\.url)
        if state(of: group) == .on { selection.subtract(urls) } else { selection.formUnion(urls) }
    }

    func moveToTrash() async {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }
        let outcome = await cleanup.remove(allItems.filter { selection.contains($0.url) }.map(\.request))
        let removed = Set(outcome.removed)
        groups = groups.compactMap { group in
            let remaining = group.items.filter { !removed.contains($0.url) }
            return remaining.isEmpty ? nil : OrphanGroup(bundleID: group.bundleID, items: remaining)
        }
        selection.subtract(removed)
        report = CleanupReport(outcome)
    }
}
