import Foundation
import Observation

/// What Início shows: the greeting, then a row of widgets in the person's order and
/// sizes. Edited in place, in the notch (see `HomeEditBar`).
@Observable
final class HomeLayout {
    private static let itemsKey = "homeWidgets"
    private static let greetingKey = "homeShowsGreeting"

    static let standard: [HomeWidgetItem] = [HomeWidgetItem(.nowPlaying), HomeWidgetItem(.agenda), HomeWidgetItem(.mirror)]

    private(set) var items: [HomeWidgetItem]
    /// The widget being dragged in edit mode.
    var dragging: HomeWidgetKind?
    var showsGreeting: Bool {
        didSet { UserDefaults.standard.set(showsGreeting, forKey: Self.greetingKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.itemsKey),
           let saved = try? JSONDecoder().decode([HomeWidgetItem].self, from: data) {
            // A size a later version dropped falls back to the widget's default.
            items = saved.map { $0.kind.sizes.contains($0.size) ? $0 : HomeWidgetItem($0.kind) }
        } else {
            items = Self.standard
        }
        showsGreeting = defaults.object(forKey: Self.greetingKey) as? Bool ?? true
    }

    /// Widgets not on Início yet, in catalog order.
    var available: [HomeWidgetKind] {
        HomeWidgetKind.allCases.filter { kind in !items.contains { $0.kind == kind } }
    }

    func add(_ kind: HomeWidgetKind) {
        guard !items.contains(where: { $0.kind == kind }) else { return }
        items.append(HomeWidgetItem(kind))
        save()
    }

    func remove(_ kind: HomeWidgetKind) {
        items.removeAll { $0.kind == kind }
        save()
    }

    func setSize(_ size: HomeWidgetSize, for kind: HomeWidgetKind) {
        guard let index = items.firstIndex(where: { $0.kind == kind }), kind.sizes.contains(size) else { return }
        items[index].size = size
        save()
    }

    /// Puts `kind` where `target` is, pushing the rest along: drag-to-reorder.
    func move(_ kind: HomeWidgetKind, to target: HomeWidgetKind) {
        guard kind != target,
              let from = items.firstIndex(where: { $0.kind == kind }),
              let to = items.firstIndex(where: { $0.kind == target })
        else { return }
        let item = items.remove(at: from)
        items.insert(item, at: to)
        save()
    }

    func reset() {
        items = Self.standard
        showsGreeting = true
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.itemsKey)
        }
    }
}
