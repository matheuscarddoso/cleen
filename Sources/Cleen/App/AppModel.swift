import AppKit
import Observation
import SwiftUI

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
    let homeLayout = HomeLayout()
    let live = LiveActivityCenter()
    let agents = AgentsModel()
    let displays = DisplaysModel()
    let fullscreen = FullscreenWatcher()
    let timer = TimerModel()
    let notes = NotesModel()
    let weather = WeatherModel()
    let shortcuts = ShortcutsModel()
    let mirror = MirrorModel()
    let clipboard = ClipboardModel()
    let screenshots = ScreenshotModel()
    @ObservationIgnored private(set) lazy var notch = NotchCoordinator(app: self)
    @ObservationIgnored private var onboarding: OnboardingController?

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
        clipboard.start()
        clipboard.onScreenshot = { [screenshots] png in screenshots.addClipboardCapture(png) }
        screenshots.onNewScreenshot = { [weak self] _ in self?.notch.present(tab: .screenshots) }
        // The closed notch shows what's playing, so listen from the start.
        Task { [nowPlaying] in await nowPlaying.watch() }
        LiveActivitySettings.register()
        nowPlaying.onTrackChange = { [live] track in live.trackChanged(track) }
        live.start(agenda: agenda)
        timer.onPhaseEnd = { [live] ended in
            switch ended {
            case .countdown: live.timerEnded(phase: String(localized: "Timer"))
            case .focus: live.timerEnded(phase: String(localized: "Foco"))
            case .shortBreak, .longBreak: live.timerEnded(phase: String(localized: "Pausa"))
            }
        }
        fullscreen.start()
        agents.onFinished = { [live] session in live.agentFinished(session.title) }
        agents.start()
        displays.restoreDimming()
        Thumbnails.shared.scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
    }

    private func installNotch() {
        if AppLocation.needsMove, AppLocation.offerMove() { return }
        notch.install()
        if OnboardingModel.isNeeded, LaunchArguments.onboarding || (!LaunchArguments.settings && LaunchArguments.notchTab == nil) {
            startOnboarding()
            return
        }
        // Watching the Mesa is what asks for access to it, so on a first run that waits
        // until the tour is over.
        screenshots.start()
        warmCharts(after: .seconds(4))
        if let kind = LaunchArguments.liveActivity {
            Task { [live] in
                try? await Task.sleep(for: .seconds(1.5))
                live.preview(kind)
            }
        }
        if LaunchArguments.settings {
            notch.primary?.state.isPinned = true
            notch.primary?.openSettings(LaunchArguments.settingsSection)
        } else if let tab = LaunchArguments.notchTab {
            notch.primary?.state.isPinned = true
            notch.primary?.open(tab: tab)
            if tab == .home, LaunchArguments.editHome { notch.primary?.state.isEditingHome = true }
            if LaunchArguments.scan { startScan(for: tab) }
        } else if LaunchArguments.scan {
            // Closed notch, scan running: shows the wing's progress.
            startScan(for: .overview)
        }
    }

    /// The first-run tour, hanging from the notch. When it folds back up, the notch
    /// opens on Início so the person lands right where the tour pointed.
    /// Swift Charts loads its framework and type metadata the first time a chart is
    /// drawn, about 200 ms on the main thread, which used to land on the first visit to
    /// Sistema. Draw one offscreen while nothing is on screen instead.
    private func warmCharts(after delay: Duration) {
        Task {
            try? await Task.sleep(for: delay)
            _ = ImageRenderer(content: Sparkline(values: [0.2, 0.6, 0.4]).frame(width: 40, height: 14)).cgImage
        }
    }

    private func startOnboarding() {
        guard let screen = notch.primary?.screen ?? NSScreen.main else { return }
        let onboarding = OnboardingController(screen: screen)
        self.onboarding = onboarding
        notch.isSuspended = true
        notch.onSuspendedHotKey = { [weak onboarding] in onboarding?.model.noteShortcut() }
        onboarding.show(app: self) { [weak self] in
            guard let self else { return }
            self.notch.isSuspended = false
            self.notch.onSuspendedHotKey = nil
            self.notch.primary?.present(tab: .home)
            self.onboarding = nil
            self.screenshots.start()
            self.warmCharts(after: .seconds(10))
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
        case .calendar, .shelf, .clipboard, .screenshots, .ai, .system, .startup, .maintenance,
             .timer, .notes, .reminders, .converter, .emoji, .weather, .shortcuts, .agents, .icons: break
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
