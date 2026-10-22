import AppKit
import Observation

/// Files dropped on the notch, kept for a day, ready to AirDrop or drag somewhere else.
@Observable
final class ShelfModel {
    static let lifetime: TimeInterval = 24 * 3600
    private static let storageKey = "shelfItems"

    private(set) var items: [ShelfItem] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            items = saved
        }
        prune()
    }

    func add(_ urls: [URL]) {
        prune()
        let existing = Set(items.map(\.url))
        let new = urls.filter { $0.isFileURL && !existing.contains($0) }.map { ShelfItem(url: $0, added: .now) }
        items.append(contentsOf: new)
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    /// Drops what's older than a day or no longer exists.
    func prune() {
        let before = items.count
        items.removeAll { Date.now.timeIntervalSince($0.added) > Self.lifetime || !FileManager.default.fileExists(atPath: $0.url.path(percentEncoded: false)) }
        if items.count != before { save() }
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
