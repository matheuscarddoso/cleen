import Foundation
import CleenKit
import Observation

@Observable
final class SpaceLensModel {
    private(set) var phase = ScanPhase.idle
    private(set) var progress: SpaceLensScanner.Progress?
    private(set) var root: SpaceNode?
    private(set) var unreadable = 0
    private(set) var target = SpaceTarget.home
    private(set) var report: CleanupReport?
    /// Ids of the folders drilled into, from the root down.
    private(set) var trail: [String] = []

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
    }

    /// The folder on screen.
    var current: SpaceNode? {
        guard var node = root else { return nil }
        for id in trail {
            guard let next = node.children.first(where: { $0.id == id }) else { break }
            node = next
        }
        return node
    }

    /// Root first, current last.
    var breadcrumbs: [SpaceNode] {
        guard var node = root else { return [] }
        var crumbs = [node]
        for id in trail {
            guard let next = node.children.first(where: { $0.id == id }) else { break }
            crumbs.append(next)
            node = next
        }
        return crumbs
    }

    func scan(_ target: SpaceTarget) {
        task?.cancel()
        self.target = target
        task = Task { await performScan() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = root == nil ? .idle : .ready
    }

    private func performScan() async {
        phase = .scanning
        progress = nil
        report = nil
        trail = []
        let scanner = SpaceLensScanner(root: target.url)
        let result = await offMain {
            scanner.scan { progress in
                Task { @MainActor [weak self] in self?.progress = progress }
            }
        }
        guard !Task.isCancelled else { return }
        root = result?.root
        unreadable = result?.unreadable ?? 0
        phase = .ready
    }

    func open(_ node: SpaceNode) {
        guard node.isNavigable else { return }
        trail.append(node.id)
    }

    /// Jumps back to a breadcrumb; index 0 is the root.
    func goBack(to index: Int) {
        trail = Array(trail.prefix(index))
    }

    func goUp() {
        _ = trail.popLast()
    }

    func moveToTrash(_ node: SpaceNode) async {
        guard !node.isAggregate else { return }
        let outcome = await cleanup.remove([RemovalRequest(url: node.url, size: node.size, mode: .trash)])
        if outcome.removed.contains(node.url) {
            root = root?.removing(node.id)
        }
        report = CleanupReport(outcome)
    }
}
