import Foundation
import Observation

/// Which tabs the notch shows and in what order, as set in Ajustes › Abas.
@Observable
final class TabPreferences {
    private static let orderKey = "notchTabOrder"
    private static let hiddenKey = "notchHiddenTabs"
    private static let pinnedKey = "notchDockTabs"
    private static let gridKey = "notchTabsInGrid"
    /// How many tools the dock holds besides the grid.
    static let maxPinned = 4

    /// Every tab, in the person's order (new tabs from updates are appended).
    private(set) var order: [NotchTab]
    private(set) var hidden: Set<NotchTab>
    /// The tools in the dock, before its grid button (Droppy keeps Home and the tray).
    private(set) var pinned: [NotchTab]

    init() {
        let defaults = UserDefaults.standard
        let saved = (defaults.stringArray(forKey: Self.orderKey) ?? []).compactMap(NotchTab.init(rawValue:))
        let added = NotchTab.allCases.filter { !saved.contains($0) }
        order = saved + added
        hidden = Set((defaults.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(NotchTab.init(rawValue:)))
            .union(added.filter(\.isHiddenByDefault))
        let savedPinned = (defaults.stringArray(forKey: Self.pinnedKey) ?? []).compactMap(NotchTab.init(rawValue:))
        pinned = defaults.object(forKey: Self.pinnedKey) == nil ? [.home, .shelf] : savedPinned
        // The grid has room for every tool: what was only kept out of the old tab row
        // (hidden by default) shows there from now on, once.
        if !defaults.bool(forKey: Self.gridKey) {
            defaults.set(true, forKey: Self.gridKey)
            hidden.removeAll()
            defaults.set([String](), forKey: Self.hiddenKey)
        }
    }

    func isPinned(_ tab: NotchTab) -> Bool { pinned.contains(tab) }

    /// Puts a tool in the dock or takes it out (Início always stays).
    func setPinned(_ pin: Bool, for tab: NotchTab) {
        if pin {
            guard !pinned.contains(tab), pinned.count < Self.maxPinned else { return }
            pinned.append(tab)
        } else if tab != .home {
            pinned.removeAll { $0 == tab }
        }
        UserDefaults.standard.set(pinned.map(\.rawValue), forKey: Self.pinnedKey)
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
        pinned = [.home, .shelf]
        UserDefaults.standard.set(pinned.map(\.rawValue), forKey: Self.pinnedKey)
        save()
    }

    private func save() {
        UserDefaults.standard.set(order.map(\.rawValue), forKey: Self.orderKey)
        UserDefaults.standard.set(hidden.map(\.rawValue), forKey: Self.hiddenKey)
    }
}
