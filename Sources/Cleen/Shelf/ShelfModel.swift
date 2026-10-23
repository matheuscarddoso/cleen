import AppKit
import CleenKit
import Observation

/// Files dropped on the notch, kept for a day, ready to AirDrop or drag somewhere else.
/// Only references: the files stay where they are.
@Observable
final class ShelfModel {
    static let lifetime: TimeInterval = 24 * 3600
    private static let storageKey = "shelfItems"

    private(set) var items: [ShelfItem] = []
    var selection = ShelfSelection<URL>()
    /// A drag out of the tray is under way. The notch sees files on the drag pasteboard
    /// then too, and must not swap the tray for the drop zones under the pointer.
    var isDraggingOut = false

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            items = saved
        }
        prune()
    }

    var urls: [URL] { items.map(\.url) }
    var selectedURLs: [URL] { selection.ordered(in: urls) }
    /// What the header's actions work on: the selection, or everything when nothing is picked.
    var targetURLs: [URL] { selection.isEmpty ? urls : selectedURLs }

    // MARK: Adding and removing

    func add(_ urls: [URL]) {
        expire()
        var seen = Set(items.map(\.url))
        let new = urls.filter(\.isFileURL).map(\.standardizedFileURL)
            .filter { seen.insert($0).inserted }
            .map { ShelfItem(url: $0, added: .now) }
        guard !new.isEmpty else { return }
        items.append(contentsOf: new)
        save()
    }

    func remove(_ urls: some Sequence<URL>) {
        let gone = Set(urls)
        guard !gone.isEmpty else { return }
        items.removeAll { gone.contains($0.url) }
        selection.keep(self.urls)
        save()
    }

    func removeSelected() {
        remove(selectedURLs)
    }

    func clear() {
        items.removeAll()
        selection.clear()
        save()
    }

    /// Drops what's older than a day now, and what no longer exists once the disk has
    /// been checked off the main thread.
    func prune() {
        expire()
        let urls = urls
        guard !urls.isEmpty else { return }
        Task {
            let missing = await offMain {
                urls.filter { !FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
            }
            remove(missing)
        }
    }

    private func expire() {
        let before = items.count
        items.removeAll { Date.now.timeIntervalSince($0.added) > Self.lifetime }
        if items.count != before {
            selection.keep(urls)
            save()
        }
    }

    // MARK: Clipboard

    /// File URLs copied in Finder (or anywhere) land on the shelf with ⌘V.
    @discardableResult
    func paste() -> Bool {
        let found = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        add(found)
        return !found.isEmpty
    }

    var canPaste: Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    func copy(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
    }

    // MARK: Actions

    func open(_ urls: [URL]) {
        urls.forEach { NSWorkspace.shared.open($0) }
    }

    func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// The file picker, for adding without dragging. The notch stays open behind it.
    func choose(holdingOpen notch: NotchState) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Adicionar à Shelf")
        panel.message = String(localized: "Os arquivos continuam onde estão; a Shelf guarda só o caminho por um dia.")
        let heldBefore = notch.holdsOpen
        notch.holdsOpen = true
        NSApp.activate()
        defer { notch.holdsOpen = heldBefore }
        guard panel.runModal() == .OK else { return }
        add(panel.urls)
    }

    /// Opens the system AirDrop sheet for the given files (everything on the shelf by default).
    func airDrop(_ urls: [URL]? = nil) {
        let files = urls ?? items.map(\.url)
        guard !files.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate()
        service.perform(withItems: files)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
