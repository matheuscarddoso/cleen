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
    let updates = UpdateModel()
    @ObservationIgnored private(set) lazy var mediaKeys = MediaKeyHUD(displays: displays)
    @ObservationIgnored private(set) lazy var search = SearchModel(app: self)
    let fullscreen = FullscreenWatcher()
    let timer = TimerModel()
    let notes = NotesModel()
    let notesSync = NotesSync()
    let weather = WeatherModel()
    let shortcuts = ShortcutsModel()
    let mirror = MirrorModel()
    let clipboard = ClipboardModel()
    let screenshots = ScreenshotModel()
    let icons = LucideModel()
    let teleprompter = TeleprompterModel()
    let voice = VoiceMeter()
    let assistant = AssistantModel()
    let stocks = StocksModel()
    @ObservationIgnored private(set) lazy var recorder = RecorderModel(app: self)
    @ObservationIgnored private var editors: [URL: EditorWindowController] = [:]
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
        agents.onApprovalRequested = { [weak self] in self?.notch.presentRequest(tab: .agents) }
        agents.onApprovalsCleared = { [weak self] in self?.notch.endRequest() }
        agents.start()
        displays.restoreDimming()
        // An update installs on its own only when swapping the app interrupts nothing.
        updates.isInUse = { [unowned self] in
            notch.controllers.contains { $0.state.isOpen } || !agents.approvals.isEmpty || timer.isActive || teleprompter.isRunning
        }
        notesSync.start(notes: notes)
        updates.start()
        mediaKeys.start()
        Thumbnails.shared.scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
    }

    /// The editor for a recording, in its own window (one per take).
    func openEditor(_ folder: URL) {
        if let editor = editors[folder] {
            editor.show()
            return
        }
        guard let editor = EditorWindowController(folder: folder, app: self) else { return }
        editor.onClose = { [weak self] in self?.editors[folder] = nil }
        editors[folder] = editor
        editor.show()
    }

    private func installNotch() {
        if AppLocation.needsMove, AppLocation.offerMove() { return }
        notch.install()
        // The commands' own shortcuts and the snippet keywords work from the start.
        search.start()
        if OnboardingModel.isNeeded, LaunchArguments.onboarding || (!LaunchArguments.settings && LaunchArguments.notchTab == nil) {
            startOnboarding()
            return
        }
        // Watching the Mesa is what asks for access to it, so on a first run that waits
        // until the tour is over.
        screenshots.start()
        warmCharts(after: .seconds(4))
        if LaunchArguments.welcome { notch.primary?.presentWelcome() }
        if LaunchArguments.focusCheck || LaunchArguments.pasteCheck != nil, let notch = notch.primary {
            notch.openSearch()
            Task {
                try? await Task.sleep(for: .seconds(2))
                // Only ever pastes into a bare test tool, never into a real app.
                guard let text = LaunchArguments.pasteCheck, PasteKeystroke.target?.bundleIdentifier == nil else { return notch.closeSearch(paste: false) }
                let pasteboard = NSPasteboard.general
                let previous = pasteboard.string(forType: .string)
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                notch.closeSearch(paste: true)
                try? await Task.sleep(for: .seconds(2))
                pasteboard.clearContents()
                if let previous { pasteboard.setString(previous, forType: .string) }
            }
        }
        if let text = LaunchArguments.prompt, let notch = notch.primary {
            if teleprompter.script.isEmpty { teleprompter.script = text }
            notch.openHeld(tab: .teleprompter)
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                teleprompter.start()
            }
        }
        if let folder = LaunchArguments.editor {
            openEditor(folder)
            if LaunchArguments.exportNow { editors[folder]?.model.exportMovie() }
        }
        switch LaunchArguments.pick {
        case "display": recorder.select(.display)
        case "window": recorder.select(.window)
        case "area": recorder.select(.area)
        default: break
        }
        if let text = LaunchArguments.search {
            notch.primary?.openSearch()
            search.query = text
        }
        if let kind = LaunchArguments.liveActivity {
            Task { [live, agents, mediaKeys] in
                try? await Task.sleep(for: .seconds(1.5))
                if kind == "agent" { agents.previewFinished() }
                if kind == "volume" { mediaKeys.preview() } else { live.preview(kind) }
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
            self.notch.primary?.presentWelcome()
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
             .timer, .notes, .reminders, .converter, .emoji, .weather, .shortcuts, .agents, .icons, .stocks, .teleprompter, .recorder, .assistant: break
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
