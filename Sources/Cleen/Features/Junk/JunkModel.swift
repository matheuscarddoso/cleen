import AppKit
import CleenKit
import Observation

@Observable
final class JunkModel {
    private(set) var phase = ScanPhase.idle
    private(set) var progress = ""
    private(set) var results: [JunkCategoryResult] = []
    private(set) var tools: [ToolCleanup] = []
    private(set) var isCleaning = false
    private(set) var report: CleanupReport?
    private(set) var lastScan: Date?
    /// What the last scan couldn't see for lack of Full Disk Access.
    private(set) var hiddenByPermission: [JunkCategory] = []

    var selection = Set<URL>()
    var selectedTools = Set<ToolCleanup.Kind>()

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
    }

    // MARK: Totals

    /// Categories and tool cleanups together, largest first — the order every list shows.
    var rows: [JunkRow] {
        (results.map(JunkRow.category) + tools.map(JunkRow.tool)).sorted { $0.size > $1.size }
    }

    /// Groups of categories for the window, the heaviest group first.
    var groups: [(group: JunkCategory.Group, results: [JunkCategoryResult])] {
        Dictionary(grouping: results, by: \.category.group)
            .map { ($0.key, $0.value) }
            .sorted { $0.1.reduce(0) { $0 + $1.totalSize } > $1.1.reduce(0) { $0 + $1.totalSize } }
    }

    var totalSize: Int64 {
        results.reduce(0) { $0 + $1.totalSize } + tools.reduce(0) { $0 + $1.reclaimable }
    }

    var selectedSize: Int64 {
        let items = results.flatMap(\.items).filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
        let toolBytes = tools.filter { selectedTools.contains($0.kind) }.reduce(0) { $0 + $1.reclaimable }
        return items + toolBytes
    }

    var selectedCount: Int {
        results.flatMap(\.items).count { selection.contains($0.url) } + selectedTools.count
    }

    /// Whether anything selected is permanently deleted rather than trashed.
    var selectionDeletes: Bool {
        results.flatMap(\.items).contains { selection.contains($0.url) && $0.removal == .delete } || !selectedTools.isEmpty
    }

    // MARK: Scanning

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

    func cancel() {
        task?.cancel()
        task = nil
        phase = results.isEmpty && tools.isEmpty ? .idle : .ready
    }

    private func performScan() async {
        phase = .scanning
        report = nil
        progress = ""
        let hidden = JunkCatalog.hiddenWithoutFullDiskAccess(granted: FullDiskAccess.isGranted)
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let scanner = JunkScanner(runningBundleIDs: running)

        let found = await scanner.scan { title in
            Task { @MainActor [weak self] in self?.progress = title }
        }
        guard !Task.isCancelled else { return }
        progress = String(localized: "Docker e simuladores")
        async let docker = DockerCleaner.inspect()
        async let simulators = SimulatorCleaner.inspect()
        let foundTools = await [docker, simulators].compactMap { $0 }
        guard !Task.isCancelled else { return }

        results = found
        hiddenByPermission = hidden
        tools = foundTools.sorted { $0.reclaimable > $1.reclaimable }
        selection = Set(found.flatMap(\.items).filter(\.selectedByDefault).map(\.url))
        selectedTools = Set(foundTools.filter(\.selectedByDefault).map(\.kind))
        lastScan = .now
        phase = .ready
    }

    // MARK: Selection

    func state(of result: JunkCategoryResult) -> CheckState {
        CheckState(selected: result.items.count { selection.contains($0.url) }, of: result.items.count)
    }

    func toggle(_ result: JunkCategoryResult) {
        let urls = result.items.map(\.url)
        if state(of: result) == .on {
            selection.subtract(urls)
        } else {
            selection.formUnion(urls)
        }
    }

    func toggle(_ item: JunkItem) {
        if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
    }

    func toggle(_ tool: ToolCleanup) {
        if selectedTools.contains(tool.kind) { selectedTools.remove(tool.kind) } else { selectedTools.insert(tool.kind) }
    }

    // MARK: Cleaning

    func clean() async {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        let requests = results.flatMap(\.items).filter { selection.contains($0.url) }.map(\.request)
        var outcome = await cleanup.remove(requests)

        var toolFailures: [RemovalFailure] = []
        var cleanedTools = Set<ToolCleanup.Kind>()
        var toolBytes: Int64 = 0
        for tool in tools where selectedTools.contains(tool.kind) {
            do {
                switch tool.kind {
                case .docker: try await DockerCleaner.clean()
                case .simulators: try await SimulatorCleaner.clean()
                }
                toolBytes += tool.reclaimable
                cleanedTools.insert(tool.kind)
            } catch {
                toolFailures.append(RemovalFailure(url: URL(filePath: "/\(tool.title)"), reason: error.localizedDescription))
            }
        }
        cleanup.recordToolCleanup(bytes: toolBytes)
        outcome.freed += toolBytes
        outcome.failures += toolFailures

        let removed = Set(outcome.removed)
        results = results.compactMap { result in
            let remaining = result.items.filter { !removed.contains($0.url) }
            return remaining.isEmpty ? nil : JunkCategoryResult(category: result.category, items: remaining)
        }
        .sorted { $0.totalSize > $1.totalSize }
        tools.removeAll { cleanedTools.contains($0.kind) }
        selection.subtract(removed)
        selectedTools.removeAll()
        report = CleanupReport(outcome)
    }
}
