import Observation

/// Owns every feature model for the life of the app, so scans keep running and results
/// survive while windows and the menu bar panel open and close.
@Observable
final class AppModel {
    /// One per process. SwiftUI may evaluate the `App`'s initial state more than once,
    /// and a second model would mean a second notch panel and a second sampling loop.
    static let shared = AppModel()

    let cleanup = CleanupService()
    let monitor = SystemMonitor()
    let lowDiskAlert = LowDiskAlert()

    let junk: JunkModel
    let projects: ProjectsModel
    let largeFiles: LargeFilesModel
    let duplicates: DuplicatesModel
    let spaceLens: SpaceLensModel
    let apps: AppsModel
    let orphans: OrphansModel
    let startup: StartupModel
    let maintenance: MaintenanceModel
    let nowPlaying = NowPlayingModel()
    let agenda = AgendaModel()
    let aiUsage = AIUsageModel()
    let shelf = ShelfModel()
    let tabs = TabPreferences()
    let mirror = MirrorModel()
    @ObservationIgnored private(set) lazy var notch = NotchCoordinator(app: self)

    private init() {
        junk = JunkModel(cleanup: cleanup)
        projects = ProjectsModel(cleanup: cleanup)
        largeFiles = LargeFilesModel(cleanup: cleanup)
        duplicates = DuplicatesModel(cleanup: cleanup)
        spaceLens = SpaceLensModel(cleanup: cleanup)
        apps = AppsModel(cleanup: cleanup)
        orphans = OrphansModel(cleanup: cleanup)
        startup = StartupModel(cleanup: cleanup)
        maintenance = MaintenanceModel()

        cleanup.onChange = { [monitor] in monitor.refreshDisk() }
        monitor.onDiskReading = { [lowDiskAlert] disk in lowDiskAlert.evaluate(disk) }
        monitor.start()
        // After the app finishes launching, so screens and the menu bar are in place.
        Task { [weak self] in self?.installNotch() }
        // The closed notch shows what's playing, so listen from the start.
        Task { [nowPlaying] in await nowPlaying.watch() }
    }

    private func installNotch() {
        notch.install()
        if LaunchArguments.settings {
            notch.primary?.state.isPinned = true
            notch.primary?.openSettings()
        } else if let tab = LaunchArguments.notchTab {
            notch.primary?.state.isPinned = true
            notch.primary?.open(tab: tab)
            if LaunchArguments.scan { startScan(for: tab) }
        }
    }

    /// Kicks off the scan behind a tab (used by `--scan`).
    func startScan(for tab: NotchTab) {
        switch tab {
        case .home, .overview: Task { await smartScan() }
        case .clean: junk.startScan()
        case .projects: projects.startScan()
        case .files: largeFiles.startScan()
        case .duplicates: duplicates.startScan()
        case .space: spaceLens.scan(.home)
        case .leftovers: orphans.startScan()
        case .apps: Task { await apps.load() }
        case .calendar, .shelf, .ai, .system, .startup, .maintenance: break
        }
    }

    // MARK: Smart scan

    private(set) var isSmartScanning = false
    private(set) var isSmartCleaning = false
    private(set) var smartReport: CleanupReport?

    var hasSmartResults: Bool { junk.phase == .ready && projects.phase == .ready }

    /// What one click in Visão geral cleans: the safe defaults of junk and stale projects.
    var smartCleanSize: Int64 { junk.selectedSize + projects.selectedSize }

    /// Runs every scan that feeds the overview at once.
    func smartScan() async {
        guard !isSmartScanning else { return }
        isSmartScanning = true
        smartReport = nil
        async let junkScan: Void = junk.scan()
        async let projectScan: Void = projects.scan()
        async let orphanScan: Void = orphans.scan()
        async let startupScan: Void = startup.scan()
        _ = await (junkScan, projectScan, orphanScan, startupScan)
        isSmartScanning = false
    }

    func smartClean() async {
        guard !isSmartCleaning else { return }
        isSmartCleaning = true
        defer { isSmartCleaning = false }
        let before = cleanup.lifetimeFreed
        await junk.clean()
        await projects.clean()
        let failures = (junk.report?.failures ?? []) + (projects.report?.failures ?? [])
        smartReport = CleanupReport(freed: cleanup.lifetimeFreed - before, failures: failures)
    }
}
