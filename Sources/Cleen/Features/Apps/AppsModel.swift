import AppKit
import CleenKit
import Observation

@Observable
final class AppsModel {
    private(set) var phase = ScanPhase.idle
    private(set) var apps: [InstalledApp] = []
    private(set) var leftovers: [Leftover] = []
    private(set) var isLoadingLeftovers = false
    private(set) var isUninstalling = false
    private(set) var report: CleanupReport?

    var search = ""
    var sort = AppSort.size
    var selectedID: InstalledApp.ID?
    var leftoverSelection = Set<URL>()

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var leftoversTask: Task<Void, Never>?

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
    }

    var selectedApp: InstalledApp? { apps.first { $0.id == selectedID } }

    var visibleApps: [InstalledApp] {
        let filtered = search.isEmpty ? apps : apps.filter { $0.name.localizedStandardContains(search) }
        return switch sort {
        case .size: filtered.sorted { $0.size > $1.size }
        case .name: filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .lastUsed: filtered.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
    }

    var totalSize: Int64 { apps.reduce(0) { $0 + $1.size } }

    var removalSize: Int64 {
        (selectedApp?.size ?? 0) + leftovers.filter { leftoverSelection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    // MARK: Loading

    func load() async {
        guard phase != .scanning else { return }
        phase = .scanning
        let bundles = AppCatalog.bundles()
        apps = await withTaskGroup(of: InstalledApp?.self) { group in
            // A few at a time: sizing an app blocks a thread, and Xcode alone is huge.
            var pending = bundles.makeIterator()
            for _ in 0..<4 {
                guard let bundle = pending.next() else { break }
                group.addTask { await offMain { AppCatalog.load(bundle) } }
            }
            var loaded: [InstalledApp] = []
            for await app in group {
                if let app { loaded.append(app) }
                if let bundle = pending.next() {
                    group.addTask { await offMain { AppCatalog.load(bundle) } }
                }
            }
            return loaded
        }
        phase = .ready
    }

    /// Finds what the selected app left around the Mac. Call after `selectedID` changes.
    func loadLeftovers() {
        leftovers = []
        leftoverSelection = []
        leftoversTask?.cancel()
        isLoadingLeftovers = false
        // Deselecting after an uninstall keeps its report on screen.
        guard let app = selectedApp else { return }
        report = nil
        isLoadingLeftovers = true
        leftoversTask = Task {
            let finder = LeftoverFinder()
            let found = await offMain { finder.leftovers(for: app) }
            guard !Task.isCancelled else { return }
            leftovers = found
            leftoverSelection = Set(found.map(\.url))
            isLoadingLeftovers = false
        }
    }

    func toggle(_ leftover: Leftover) {
        if leftoverSelection.contains(leftover.url) { leftoverSelection.remove(leftover.url) } else { leftoverSelection.insert(leftover.url) }
    }

    // MARK: Uninstalling

    func isRunning(_ app: InstalledApp) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
    }

    /// Quits the app, then moves it and the selected leftovers to the Trash. Root-owned
    /// pieces go in one batch behind a single password prompt.
    func uninstall() async {
        guard let app = selectedApp, !app.isSystem, !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        await quit(app)

        let chosen = leftovers.filter { leftoverSelection.contains($0.url) }
        let appRequest = RemovalRequest(url: app.url, size: app.size, mode: .trash)
        let userRequests = [appRequest] + chosen.filter { !$0.place.isSystemWide }.map(\.request)
        let systemRequests = chosen.filter(\.place.isSystemWide).map(\.request)

        var outcome = RemovalOutcome()
        if app.needsAdministrator {
            outcome.merge(await cleanup.remove(Array(userRequests.dropFirst())))
            outcome.merge(await cleanup.removeAsAdministrator([appRequest] + systemRequests))
        } else {
            outcome.merge(await cleanup.remove(userRequests))
            if !systemRequests.isEmpty {
                outcome.merge(await cleanup.removeAsAdministrator(systemRequests))
            }
        }

        report = CleanupReport(outcome)
        let removed = Set(outcome.removed)
        if removed.contains(app.url) {
            apps.removeAll { $0.id == app.id }
            selectedID = nil
        }
        leftovers.removeAll { removed.contains($0.url) }
        leftoverSelection.subtract(removed)
    }

    /// Removes only the selected leftovers and keeps the app: a clean slate for an app
    /// that misbehaves.
    func reset() async {
        guard let app = selectedApp, !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }
        await quit(app)
        let chosen = leftovers.filter { leftoverSelection.contains($0.url) && !$0.place.isSystemWide }
        let outcome = await cleanup.remove(chosen.map(\.request))
        report = CleanupReport(outcome)
        let removed = Set(outcome.removed)
        leftovers.removeAll { removed.contains($0.url) }
        leftoverSelection.subtract(removed)
    }

    private func quit(_ app: InstalledApp) async {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }
        for _ in 0..<20 where running.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}
