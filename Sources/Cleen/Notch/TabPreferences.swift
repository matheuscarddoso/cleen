import Foundation
import Observation

/// Which tabs the notch shows and in what order, as set in Ajustes › Abas.
@Observable
final class TabPreferences {
    private static let orderKey = "notchTabOrder"
    private static let hiddenKey = "notchHiddenTabs"

    /// Every tab, in the person's order (new tabs from updates are appended).
    private(set) var order: [NotchTab]
    private(set) var hidden: Set<NotchTab>

    init() {
        let defaults = UserDefaults.standard
        let saved = (defaults.stringArray(forKey: Self.orderKey) ?? []).compactMap(NotchTab.init(rawValue:))
        let added = NotchTab.allCases.filter { !saved.contains($0) }
        order = saved + added
        hidden = Set((defaults.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(NotchTab.init(rawValue:)))
            .union(added.filter(\.isHiddenByDefault))
    }

    var visible: [NotchTab] { order.filter { !hidden.contains($0) } }

    func isVisible(_ tab: NotchTab) -> Bool { !hidden.contains(tab) }

    /// Shows or hides a tab; the last visible one can't be hidden.
    func setVisible(_ visible: Bool, for tab: NotchTab) {
        if visible {
            hidden.remove(tab)
        } else if self.visible.count > 1 {
            hidden.insert(tab)
        }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func reset() {
        order = NotchTab.allCases
        hidden = Set(NotchTab.allCases.filter(\.isHiddenByDefault))
        save()
    }

    private func save() {
        UserDefaults.standard.set(order.map(\.rawValue), forKey: Self.orderKey)
        UserDefaults.standard.set(hidden.map(\.rawValue), forKey: Self.hiddenKey)
    }
}
