import CleenKit
import AppKit
import Observation
import os

/// Every screenshot, however it was taken: files from the screenshot shortcuts and the
/// Screenshot app (see `ScreenshotFolderWatcher`), and clipboard-only captures (the ⌃
/// shortcuts), which the clipboard watcher reports.
@Observable
final class ScreenshotModel {
    static let opensNotchKey = "screenshotOpensNotch"
    static let copiesOnCaptureKey = "screenshotCopiesOnCapture"
    /// Set once Cleen has replaced the native thumbnail, so it only happens on install.
    private static let tookOverThumbnailKey = "screenshotTookOverThumbnail"

    /// What happens to each capture, for Console (`subsystem:app.cleen.Cleen category:screenshots`).
    static let log = Logger(subsystem: "app.cleen.Cleen", category: "screenshots")

    private(set) var items: [Screenshot] = []
    var selectedID: URL?
    /// Called for each new capture, so the notch can open on it.
    @ObservationIgnored var onNewScreenshot: (Screenshot) -> Void = { _ in }

    @ObservationIgnored private var watcher: ScreenshotFolderWatcher?
    /// Cleen's own copy lands on the clipboard while the capture service is still
    /// running; it must not come back as a "clipboard screenshot".
    @ObservationIgnored private var ignoreClipboardUntil = Date.distantPast
    @ObservationIgnored private var known = Set<URL>()
    /// Files of one capture still arriving (⌘⇧3 writes one per display, a few ms apart),
    /// and the moment that settles them.
    @ObservationIgnored private var landing: [ScreenshotFolderWatcher.Capture] = []
    @ObservationIgnored private var landingTask: Task<Void, Never>?
    /// Their decoding, started as each lands so it's done by the time one is picked.
    @ObservationIgnored private var landingDecodes: [URL: Task<Void, Never>] = [:]
    /// How long the files of one capture take to land, all of them.
    private static let landingWindow = Duration.milliseconds(150)
    @ObservationIgnored private let clipboardFolder = URL.applicationSupportDirectory.appending(path: "app.cleen.Cleen/Screenshots", directoryHint: .isDirectory)

    init() {
        UserDefaults.standard.register(defaults: [Self.opensNotchKey: true, Self.copiesOnCaptureKey: false])
    }

    var selected: Screenshot? { items.first { $0.id == selectedID } ?? items.first }

    /// macOS keeps a capture in memory (not on disk) while its floating thumbnail shows,
    /// so the file — and Cleen — only arrive when the thumbnail goes away.
    private(set) var nativeThumbnailOn = ScreenshotModel.readNativeThumbnail()

    private static func readNativeThumbnail() -> Bool {
        UserDefaults(suiteName: "com.apple.screencapture")?.object(forKey: "show-thumbnail") as? Bool ?? true
    }

    /// Turns the native floating thumbnail on or off (the same switch as "Show Floating
    /// Thumbnail" in ⌘⇧5's Options). Only ever called from the person's own tap.
    func setNativeThumbnail(_ on: Bool) async {
        _ = try? await Shell.run("/usr/bin/defaults", ["write", "com.apple.screencapture", "show-thumbnail", "-bool", on ? "true" : "false"])
        nativeThumbnailOn = Self.readNativeThumbnail()
    }

    /// Cleen's own screenshot panel replaces the native floating thumbnail: with it on,
    /// macOS holds the file back until it fades. Done once; the switch in Ajustes brings
    /// the native one back.
    private func takeOverThumbnailOnFirstRun() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.tookOverThumbnailKey) else { return }
        defaults.set(true, forKey: Self.tookOverThumbnailKey)
        if nativeThumbnailOn { await setNativeThumbnail(false) }
    }

    func refreshNativeThumbnail() {
        nativeThumbnailOn = Self.readNativeThumbnail()
    }

    func start() {
        guard watcher == nil else { return }
        Task { await takeOverThumbnailOnFirstRun() }
        let watcher = ScreenshotFolderWatcher(
            onCaptures: { [weak self] captures in
                Task { @MainActor in self?.arrived(captures) }
            },
            // The full listing that follows: files that went away, and anything the
            // quick path missed (announced only if it's new and recent).
            onChange: { [weak self] in
                Task { @MainActor in self?.reload(announcing: true) }
            }
        )
        self.watcher = watcher
        watcher.start()
        reload(announcing: false)
    }

    /// Lists the folders off the main thread (the Desktop can hold thousands of files,
    /// each checked for the screenshot tag), then updates the list.
    private func reload(announcing: Bool) {
        let since = Date.now.addingTimeInterval(-7 * 86_400)
        Task {
            let found = await offMain { ScreenshotFolderWatcher.captures(since: since) }
            apply(found, announcing: announcing)
        }
    }

    private func apply(_ found: [(url: URL, date: Date)], announcing: Bool) {
        let files = found.map { Screenshot(url: $0.url, date: $0.date, fromClipboard: false) }
        let clipboard = items.filter(\.fromClipboard)
        let merged = (files + clipboard).sorted { $0.date > $1.date }
        let new = merged.filter { !known.contains($0.url) }
        items = Array(merged.prefix(40))
        known.formUnion(merged.map(\.url))
        Thumbnails.shared.prefetch(items.map(\.url))
        guard announcing, let newest = new.first(where: { Date.now.timeIntervalSince($0.date) < 60 }) else { return }
        announce(newest)
    }

    /// Captures that just landed, straight from the watcher: listed at once. The files of
    /// one capture land a few milliseconds apart, so the notch waits for all of them, picks
    /// the one for the display it opens on, decodes it, and only then opens on it.
    private func arrived(_ captures: [ScreenshotFolderWatcher.Capture]) {
        let fresh = captures.filter { !known.contains($0.url) }
        Self.log.info("landed \(captures.count) file(s), \(fresh.count) new")
        guard !fresh.isEmpty else { return }
        known.formUnion(fresh.map(\.url))
        let shots = fresh.map { Screenshot(url: $0.url, date: $0.date, fromClipboard: false) }
        items = Array((shots + items).sorted { $0.date > $1.date }.prefix(40))
        landing += fresh
        for capture in fresh {
            landingDecodes[capture.url] = Task { await Thumbnails.shared.prepare(capture.url) }
        }
        landingTask?.cancel()
        landingTask = Task { [weak self] in
            try? await Task.sleep(for: Self.landingWindow)
            guard !Task.isCancelled, let self else { return }
            let captures = landing
            let decodes = landingDecodes
            landing = []
            landingDecodes = [:]
            let shown = captures[Self.indexForPointerScreen(captures)]
            await decodes[shown.url]?.value
            announce(Screenshot(url: shown.url, date: shown.date, fromClipboard: false))
        }
    }

    /// The capture of the display under the pointer, where the notch opens (⌘⇧3 writes one
    /// file per display); the newest when that can't be told.
    private static func indexForPointerScreen(_ captures: [ScreenshotFolderWatcher.Capture]) -> Int {
        guard captures.count > 1,
              let main = NSScreen.screens.first,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        else { return 0 }
        let display = ScreenCapturePicker.globalRect(ofScreenFrame: screen.frame, mainScreenHeight: main.frame.height)
        return ScreenCapturePicker.index(for: display, among: captures.map(\.rect)) ?? 0
    }

    /// A capture that only went to the clipboard; saved so it can be shared or AirDropped.
    func addClipboardCapture(_ png: Data) {
        guard Date.now > ignoreClipboardUntil else { return }
        try? FileManager.default.createDirectory(at: clipboardFolder, withIntermediateDirectories: true)
        let name = "Screenshot \(Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacing(":", with: ".")).png"
        let url = clipboardFolder.appending(path: name)
        guard (try? png.write(to: url, options: .atomic)) != nil else { return }
        let shot = Screenshot(url: url, date: .now, fromClipboard: true)
        known.insert(url)
        items.insert(shot, at: 0)
        Task {
            await Thumbnails.shared.prepare(url)
            announce(shot)
        }
    }

    private func announce(_ shot: Screenshot) {
        let opens = UserDefaults.standard.bool(forKey: Self.opensNotchKey)
        Self.log.info("announcing \(shot.url.lastPathComponent, privacy: .private), opens the notch: \(opens)")
        selectedID = shot.id
        if !shot.fromClipboard, UserDefaults.standard.bool(forKey: Self.copiesOnCaptureKey) {
            copy(shot)
        }
        if UserDefaults.standard.bool(forKey: Self.opensNotchKey) { onNewScreenshot(shot) }
    }

    // MARK: Actions

    func copy(_ shot: Screenshot) {
        guard let image = NSImage(contentsOf: shot.url) else { return }
        ignoreClipboardUntil = .now.addingTimeInterval(5)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image, shot.url as NSURL])
    }

    func airDrop(_ shot: Screenshot) {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate()
        service.perform(withItems: [shot.url])
    }

    func reveal(_ shot: Screenshot) {
        NSWorkspace.shared.activateFileViewerSelecting([shot.url])
    }

    /// Moves the file to the Trash (recoverable) and drops it from the list.
    func delete(_ shot: Screenshot) {
        do {
            if shot.fromClipboard {
                try FileManager.default.removeItem(at: shot.url)
            } else {
                try FileManager.default.trashItem(at: shot.url, resultingItemURL: nil)
            }
        } catch {
            return
        }
        items.removeAll { $0.id == shot.id }
        if selectedID == shot.id { selectedID = items.first?.id }
    }
}
