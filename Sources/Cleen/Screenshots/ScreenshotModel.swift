import CleenKit
import AppKit
import Observation

/// Every screenshot, however it was taken: files from the screenshot shortcuts and the
/// Screenshot app (see `ScreenshotFolderWatcher`), and clipboard-only captures (the ⌃
/// shortcuts), which the clipboard watcher reports.
@Observable
final class ScreenshotModel {
    static let opensNotchKey = "screenshotOpensNotch"
    static let copiesOnCaptureKey = "screenshotCopiesOnCapture"

    private(set) var items: [Screenshot] = []
    var selectedID: URL?
    /// Called for each new capture, so the notch can open on it.
    @ObservationIgnored var onNewScreenshot: (Screenshot) -> Void = { _ in }

    @ObservationIgnored private var watcher: ScreenshotFolderWatcher?
    /// Cleen's own copy lands on the clipboard while the capture service is still
    /// running; it must not come back as a "clipboard screenshot".
    @ObservationIgnored private var ignoreClipboardUntil = Date.distantPast
    @ObservationIgnored private var known = Set<URL>()
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

    func refreshNativeThumbnail() {
        nativeThumbnailOn = Self.readNativeThumbnail()
    }

    func start() {
        guard watcher == nil else { return }
        let watcher = ScreenshotFolderWatcher { [weak self] in
            Task { @MainActor in self?.reload(announcing: true) }
        }
        self.watcher = watcher
        watcher.start()
        reload(announcing: false)
    }

    private func reload(announcing: Bool) {
        let since = Date.now.addingTimeInterval(-7 * 86_400)
        let files = ScreenshotFolderWatcher.captures(since: since).map { Screenshot(url: $0.url, date: $0.date, fromClipboard: false) }
        let clipboard = items.filter(\.fromClipboard)
        let merged = (files + clipboard).sorted { $0.date > $1.date }
        let new = merged.filter { !known.contains($0.url) }
        items = Array(merged.prefix(40))
        known.formUnion(merged.map(\.url))
        guard announcing, let newest = new.first(where: { Date.now.timeIntervalSince($0.date) < 60 }) else { return }
        announce(newest)
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
        announce(shot)
    }

    private func announce(_ shot: Screenshot) {
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
