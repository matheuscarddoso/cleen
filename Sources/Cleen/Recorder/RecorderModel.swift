import AppKit
import AVFoundation
import CleenKit
import Observation
import os
import ScreenCaptureKit

/// Screen recording, Screen Studio style: pick a display, a window, an area or a plugged-in
/// iPhone; the camera, the microphone and the Mac's sound are recorded alongside, each in
/// its own track, with the pointer's path. When it stops, the editor opens on the take.
@Observable
final class RecorderModel {
    enum State: Equatable {
        case idle
        /// Choosing an area on screen.
        case picking
        case countdown(Int)
        case recording(since: Date)
        /// Closing the files and writing the project.
        case finishing
        case failed(String)
    }

    enum Target {
        case display(SCDisplay)
        case window(SCWindow)
        case area(SCDisplay, CGRect)
        case device(CaptureDevices.Device)
    }

    private(set) var state = State.idle
    /// The take just finished, for the quick share card.
    private(set) var lastRecording: URL?

    // MARK: Options (kept between launches)

    var cameraID: String? {
        didSet {
            defaults.set(cameraID, forKey: Keys.camera)
            refreshCamera()
        }
    }
    var showsCameraPreview: Bool {
        didSet {
            defaults.set(showsCameraPreview, forKey: Keys.cameraPreview)
            refreshCamera()
        }
    }
    /// 720, 1080 or 2160 lines.
    var cameraMaxHeight: Int {
        didSet {
            defaults.set(cameraMaxHeight, forKey: Keys.cameraHeight)
            refreshCamera()
        }
    }
    var microphoneID: String? { didSet { defaults.set(microphoneID, forKey: Keys.microphone) } }
    var recordsSystemAudio: Bool { didSet { defaults.set(recordsSystemAudio, forKey: Keys.systemAudio) } }
    /// Seconds; 0 starts at once.
    var countdown: Int { didSet { defaults.set(countdown, forKey: Keys.countdown) } }
    var hidesDesktopIcons: Bool { didSet { defaults.set(hidesDesktopIcons, forKey: Keys.desktopIcons) } }
    var hidesDock: Bool { didSet { defaults.set(hidesDock, forKey: Keys.dock) } }
    var highlightsArea: Bool { didSet { defaults.set(highlightsArea, forKey: Keys.highlight) } }
    var showsSpeakerNotes: Bool { didSet { defaults.set(showsSpeakerNotes, forKey: Keys.speakerNotes) } }
    var opensQuickShare: Bool { didSet { defaults.set(opensQuickShare, forKey: Keys.quickShare) } }
    var framesPerSecond: Int { didSet { defaults.set(framesPerSecond, forKey: Keys.fps) } }

    /// Where recordings go: Filmes › Cleen.
    static let folder = URL.moviesDirectory.appending(path: "Cleen", directoryHint: .isDirectory)

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let overlays = RecorderOverlays()
    @ObservationIgnored private var screen: ScreenCapture?
    @ObservationIgnored private var camera: CameraCapture?
    @ObservationIgnored private var device: CameraCapture?
    @ObservationIgnored private var cursor: CursorRecorder?
    @ObservationIgnored private var take: (folder: URL, source: RecordingProject.Source, size: CGSize)?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    /// Gravar is on screen: the chosen camera shows its preview, as in Screen Studio.
    @ObservationIgnored private var tabIsVisible = false
    /// A take is starting or running: the camera stays on whatever else happens.
    @ObservationIgnored private var holdsCamera = false
    /// What the running camera session was set up with.
    @ObservationIgnored private var cameraSetup: (id: String, height: Int)?
    @ObservationIgnored private var previewHide: Task<Void, Never>?
    @ObservationIgnored private unowned let app: AppModel
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "recorder")

    private enum Keys {
        static let camera = "recorder.camera"
        static let cameraPreview = "recorder.cameraPreview"
        static let cameraHeight = "recorder.cameraHeight"
        static let microphone = "recorder.microphone"
        static let systemAudio = "recorder.systemAudio"
        static let countdown = "recorder.countdown"
        static let desktopIcons = "recorder.hidesDesktopIcons"
        static let dock = "recorder.hidesDock"
        static let highlight = "recorder.highlightsArea"
        static let speakerNotes = "recorder.showsSpeakerNotes"
        static let quickShare = "recorder.opensQuickShare"
        static let fps = "recorder.fps"
    }

    init(app: AppModel) {
        self.app = app
        defaults.register(defaults: [
            Keys.cameraPreview: true, Keys.cameraHeight: 1080, Keys.countdown: 3, Keys.dock: false,
            Keys.highlight: true, Keys.quickShare: true, Keys.fps: 60,
        ])
        cameraID = defaults.string(forKey: Keys.camera)
        showsCameraPreview = defaults.bool(forKey: Keys.cameraPreview)
        cameraMaxHeight = defaults.integer(forKey: Keys.cameraHeight)
        microphoneID = defaults.string(forKey: Keys.microphone)
        recordsSystemAudio = defaults.bool(forKey: Keys.systemAudio)
        countdown = defaults.integer(forKey: Keys.countdown)
        hidesDesktopIcons = defaults.bool(forKey: Keys.desktopIcons)
        hidesDock = defaults.bool(forKey: Keys.dock)
        highlightsArea = defaults.bool(forKey: Keys.highlight)
        showsSpeakerNotes = defaults.bool(forKey: Keys.speakerNotes)
        opensQuickShare = defaults.bool(forKey: Keys.quickShare)
        framesPerSecond = defaults.integer(forKey: Keys.fps)
        // A recording cut short by a crash may have left the Dock hidden.
        Task { await DockHider.restore() }
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isBusy: Bool { state != .idle && !isFailed }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    var recordingStart: Date? {
        if case .recording(let since) = state { return since }
        return nil
    }

    func dismissError() {
        if isFailed { state = .idle }
    }

    // MARK: Sources

    /// Displays and windows that can be recorded (Cleen's own left out).
    func shareableContent() async -> SCShareableContent? {
        try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
    }

    /// Windows worth listing: titled, normal, of other apps, front to back.
    func recordableWindows(in content: SCShareableContent) -> [SCWindow] {
        let own = ProcessInfo.processInfo.processIdentifier
        return content.windows.filter { window in
            window.windowLayer == 0 && window.isOnScreen && window.frame.width > 120 && window.frame.height > 80
                && window.owningApplication?.processID != own && !(window.title ?? "").isEmpty
        }
    }

    /// The screen recording permission; macOS shows its own prompt the first time.
    var hasScreenAccess: Bool { CGPreflightScreenCaptureAccess() }

    func requestScreenAccess() {
        if !CGRequestScreenCaptureAccess(), let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Area mode: drag a rectangle, then record it.
    func pickArea() {
        guard !isBusy else { return }
        state = .picking
        app.notch.closeAll()
        Task {
            guard let pick = await AreaPicker().pick() else {
                state = .idle
                return
            }
            guard let content = await shareableContent(),
                  let display = content.displays.first(where: { $0.displayID == pick.screen.displayID ?? 0 }) else {
                state = .failed(String(localized: "Não deu para gravar essa tela."))
                return
            }
            state = .idle
            record(.area(display, pick.rect))
        }
    }

    // MARK: Recording

    /// Records `target`; the countdown (and only the countdown) can be cut short with
    /// `cancelCountdown`.
    func record(_ target: Target) {
        guard !isBusy else { return }
        countdownTask = Task { await start(target) }
    }

    private func start(_ target: Target) async {
        guard !isBusy else { return }
        if case .device = target {} else {
            guard hasScreenAccess else {
                requestScreenAccess()
                state = .failed(String(localized: "Permita a gravação de tela para o Cleen em Ajustes do Sistema › Privacidade e Segurança e tente de novo."))
                return
            }
        }
        if cameraID != nil, !(await CaptureDevices.request(.video)) {
            state = .failed(String(localized: "Permita a câmera para o Cleen em Ajustes do Sistema › Privacidade e Segurança."))
            return
        }
        if microphoneID != nil, !(await CaptureDevices.request(.audio)) {
            state = .failed(String(localized: "Permita o microfone para o Cleen em Ajustes do Sistema › Privacidade e Segurança."))
            return
        }
        holdsCamera = true
        refreshCamera()
        app.notch.closeAll()
        let folder = RecordingProject.newFolder(in: Self.folder, prefix: String(localized: "Gravação"))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await prepare(target, in: folder)
            try await runCountdown(on: screen(of: target))
            try await begin(target, in: folder)
        } catch {
            if !(error is CancellationError) { Self.log.error("start failed: \(error.localizedDescription, privacy: .public)") }
            await releaseCamera()
            await tearDown()
            // Nothing worth keeping was written yet: the folder goes.
            try? FileManager.default.removeItem(at: folder)
            take = nil
            state = error is CancellationError ? .idle : .failed(error.localizedDescription)
        }
    }

    /// The camera warms up and the helpers go on screen before the countdown, so the
    /// first second of the take already has them.
    private func prepare(_ target: Target, in folder: URL) async throws {
        if cameraID != nil, camera == nil { throw CameraCapture.CameraError.unavailable }
        if hidesDesktopIcons { overlays.coverDesktopIcons() }
        if hidesDock { await DockHider.hide() }
        if highlightsArea, let rect = globalRect(of: target), !isWholeDisplay(target) { overlays.showHighlight(rect) }
    }

    private func runCountdown(on screen: NSScreen) async throws {
        guard countdown > 0 else { return }
        for value in stride(from: countdown, through: 1, by: -1) {
            state = .countdown(value)
            overlays.showCountdown(value, on: screen)
            try await Task.sleep(for: .seconds(1))
        }
        overlays.hideCountdown()
    }

    /// Skips what's left of the countdown.
    func cancelCountdown() {
        countdownTask?.cancel()
    }

    private func begin(_ target: Target, in folder: URL) async throws {
        let screenURL = folder.appending(path: RecordingProject.screenName)
        switch target {
        case .device(let mobile):
            guard let capture = CaptureDevices.device(mobile.id) else { throw CameraCapture.CameraError.unavailable }
            let recorder = CameraCapture()
            try recorder.configure(device: capture, maxHeight: 2160)
            let size = capture.activeFormat.formatDescription.dimensions
            take = (folder, .device, CGSize(width: Int(size.width), height: Int(size.height)))
            try await recorder.start(to: screenURL)
            device = recorder
        case .display, .window, .area:
            let capture = ScreenCapture()
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let own = ProcessInfo.processInfo.processIdentifier
            let covers = overlays.coverWindowNumbers
            // Cleen's own windows stay out (the notch, the helpers), except the wallpaper
            // cover, which is the point of hiding the icons.
            let excluded = content.windows.filter { $0.owningApplication?.processID == own && !covers.contains(Int($0.windowID)) }
            guard let captureTarget = Self.captureTarget(target) else { return }
            let options = ScreenCapture.Options(framesPerSecond: framesPerSecond, systemAudio: recordsSystemAudio, microphoneID: microphoneID)
            try await capture.start(captureTarget, excluding: excluded, options: options, to: screenURL)
            screen = capture
            take = (folder, source(of: target), capture.contentSize)
            let cursor = CursorRecorder { [weak self] in self?.globalRect(of: target) ?? .zero }
            cursor.begin()
            self.cursor = cursor
        }
        if let camera {
            try await camera.start(to: folder.appending(path: RecordingProject.cameraName))
        }
        if showsSpeakerNotes {
            app.notch.openHeld(tab: .teleprompter)
            app.teleprompter.start()
        }
        state = .recording(since: .now)
    }

    /// Stops, writes the project and opens it in the editor.
    func stop() async {
        guard isRecording, let take else { return }
        state = .finishing
        let track = cursor?.end() ?? CursorTrack()
        cursor = nil
        do {
            try await screen?.stop()
            try await device?.stop()
            try await camera?.stop()
        } catch {
            Self.log.error("stop failed: \(error.localizedDescription, privacy: .public)")
        }
        screen = nil
        device = nil
        let hadCamera = camera != nil
        await releaseCamera()
        await tearDown()
        do {
            let project = try await makeProject(take: take, track: track, hasCamera: hadCamera)
            try project.save(to: take.folder)
            lastRecording = take.folder
            self.take = nil
            state = .idle
            app.openEditor(take.folder)
            if opensQuickShare { app.notch.present(tab: .recorder) }
        } catch {
            self.take = nil
            state = .failed(error.localizedDescription)
        }
    }

    /// Throws the take away (after the review in the notch).
    func discard() async {
        guard isRecording, let take else { return }
        state = .finishing
        _ = cursor?.end()
        cursor = nil
        try? await screen?.stop()
        try? await device?.stop()
        screen = nil
        device = nil
        await releaseCamera()
        await tearDown()
        try? FileManager.default.removeItem(at: take.folder)
        self.take = nil
        state = .idle
    }


    // MARK: Camera

    /// Gravar appeared: the camera's preview comes up (Screen Studio shows it as soon as
    /// a camera is picked).
    func tabAppeared() {
        tabIsVisible = true
        previewHide?.cancel()
        refreshCamera()
    }

    /// Gravar went away: a moment later (it may just be switching), the camera goes off,
    /// unless a take holds it.
    func tabDisappeared() {
        tabIsVisible = false
        previewHide?.cancel()
        previewHide = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            refreshCamera()
        }
    }

    /// Runs the camera, and its preview, exactly while they're wanted: a camera is picked
    /// and Gravar is on screen or a take is under way.
    private func refreshCamera() {
        guard let cameraID, tabIsVisible || holdsCamera else {
            if !holdsCamera { dropCamera() }
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            Task {
                if await CaptureDevices.request(.video) { refreshCamera() }
            }
            return
        default:
            return
        }
        if cameraSetup?.id != cameraID || cameraSetup?.height != cameraMaxHeight {
            // Never swapped in the middle of a take.
            guard !isRecording else { return }
            dropCamera()
            guard let device = CaptureDevices.device(cameraID) else { return }
            let camera = CameraCapture()
            do {
                try camera.configure(device: device, maxHeight: cameraMaxHeight)
            } catch {
                Self.log.error("camera setup failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            camera.startSession()
            self.camera = camera
            cameraSetup = (cameraID, cameraMaxHeight)
        }
        if showsCameraPreview, let camera {
            overlays.showCamera(session: camera.session, on: pointerScreen)
        } else {
            overlays.hideCamera()
        }
    }

    private func dropCamera() {
        overlays.hideCamera()
        camera?.stopSession()
        camera = nil
        cameraSetup = nil
    }

    /// After a take: the recording output is closed, the session goes, and the preview
    /// comes back if Gravar is still open.
    private func releaseCamera() async {
        try? await camera?.stop()
        camera = nil
        cameraSetup = nil
        holdsCamera = false
        overlays.hideCamera()
        refreshCamera()
    }

    /// The screen the pointer (and so the notch in use) is on.
    private var pointerScreen: NSScreen {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func tearDown() async {
        overlays.hideHighlight()
        overlays.uncoverDesktopIcons()
        overlays.hideCountdown()
        if hidesDock { await DockHider.restore() }
        if showsSpeakerNotes, app.teleprompter.isRunning { app.teleprompter.stop() }
    }

    private func makeProject(take: (folder: URL, source: RecordingProject.Source, size: CGSize), track: CursorTrack, hasCamera: Bool) async throws -> RecordingProject {
        let asset = AVURLAsset(url: take.folder.appending(path: RecordingProject.screenName))
        let duration = try await asset.load(.duration).seconds
        // Assumed order of the tracks ScreenCaptureKit writes: the Mac's sound, then the microphone.
        let audio: [RecordingProject.AudioSource] = take.source == .device ? [.microphone]
            : (recordsSystemAudio ? [.system] : []) + (microphoneID != nil ? [.microphone] : [])
        var project = RecordingProject(source: take.source, sourceSize: take.size, duration: duration, hasCamera: hasCamera, audio: audio)
        if take.source != .device {
            let data = try JSONEncoder().encode(track)
            try data.write(to: take.folder.appending(path: RecordingProject.cursorName), options: .atomic)
            project.zoom = ZoomPlanner.automatic(clicks: track.clicks, duration: duration, scale: project.style.zoomScale)
        } else {
            project.style.showsCursor = false
            project.style.autoZoom = false
        }
        project.style.camera.isVisible = hasCamera
        return project
    }

    // MARK: Geometry

    private static func captureTarget(_ target: Target) -> ScreenCapture.Target? {
        switch target {
        case .display(let display): .display(display, area: nil)
        case .area(let display, let rect): .display(display, area: rect)
        case .window(let window): .window(window)
        case .device: nil
        }
    }

    private func source(of target: Target) -> RecordingProject.Source {
        switch target {
        case .display: .display
        case .window: .window
        case .area: .area
        case .device: .device
        }
    }

    private func isWholeDisplay(_ target: Target) -> Bool {
        if case .display = target { return true }
        if case .device = target { return true }
        return false
    }

    /// The recorded area in global points, top-left origin.
    private func globalRect(of target: Target) -> CGRect? {
        switch target {
        case .display(let display): display.frame
        case .area(let display, let rect): rect.offsetBy(dx: display.frame.minX, dy: display.frame.minY)
        case .window(let window): Self.currentFrame(of: window.windowID) ?? window.frame
        case .device: nil
        }
    }

    /// A window's frame now (it may have moved since the recording started).
    private static func currentFrame(of id: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let bounds = info.first?[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
        return rect
    }

    private func screen(of target: Target) -> NSScreen {
        guard let rect = globalRect(of: target) else { return NSScreen.main ?? NSScreen.screens[0] }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let center = CGPoint(x: rect.midX, y: primaryHeight - rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
