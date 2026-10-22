import Observation

/// Owns every feature model for the life of the app, so scans keep running and results
/// survive while windows and the menu bar panel open and close.
@Observable
final class AppModel {
    var route = LaunchArguments.route ?? .overview

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

    init() {
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
        if LaunchArguments.scan { startScan(for: route) }
    }

    /// Kicks off the scan behind a section (used by `--scan`).
    func startScan(for route: Route) {
        switch route {
        case .overview: Task { await smartScan() }
        case .junk: junk.startScan()
        case .projects: projects.startScan()
        case .largeFiles: largeFiles.startScan()
        case .duplicates: duplicates.startScan()
        case .spaceLens: spaceLens.scan(.home)
        case .leftovers: orphans.startScan()
        case .uninstaller, .startup, .monitor, .maintenance, .settings: break
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
