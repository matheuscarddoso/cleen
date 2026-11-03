import Foundation
import Observation

/// Which tabs the notch shows and in what order, as set in Ajustes › Abas.
@Observable
final class TabPreferences {
    private static let orderKey = "notchTabOrder"
    private static let hiddenKey = "notchHiddenTabs"
    private static let pinnedKey = "notchDockTabs"
    private static let gridKey = "notchTabsInGrid"
    private static let expandedKey = "notchDockExpanded"
    /// How many tools the folded dock holds: enough for a day's favourites while it stays
    /// a compact pill under the panel.
    static let maxPinned = 8

    /// Every tab, in the person's order (new tabs from updates are appended).
    private(set) var order: [NotchTab]
    private(set) var hidden: Set<NotchTab>
    /// The tools the folded dock shows, before its expand button (Droppy keeps Home and the
    /// tray).
    private(set) var pinned: [NotchTab]
    /// The dock shows every tool, not just the pinned ones. Kept across openings and
    /// launches: whoever expanded it finds it expanded.
    var isDockExpanded: Bool {
        didSet { UserDefaults.standard.set(isDockExpanded, forKey: Self.expandedKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        let saved = (defaults.stringArray(forKey: Self.orderKey) ?? []).compactMap(NotchTab.init(rawValue:))
        let added = NotchTab.allCases.filter { !saved.contains($0) }
        order = saved + added
        hidden = Set((defaults.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(NotchTab.init(rawValue:)))
            .union(added.filter(\.isHiddenByDefault))
        let savedPinned = (defaults.stringArray(forKey: Self.pinnedKey) ?? []).compactMap(NotchTab.init(rawValue:))
        pinned = defaults.object(forKey: Self.pinnedKey) == nil ? [.home, .shelf] : savedPinned
        isDockExpanded = defaults.bool(forKey: Self.expandedKey)
        // The grid has room for every tool: what was only kept out of the old tab row
        // (hidden by default) shows there from now on, once.
        if !defaults.bool(forKey: Self.gridKey) {
            defaults.set(true, forKey: Self.gridKey)
            hidden.removeAll()
            defaults.set([String](), forKey: Self.hiddenKey)
        }
    }

    func isPinned(_ tab: NotchTab) -> Bool { pinned.contains(tab) }

    /// Another tool fits in the folded dock.
    var canPin: Bool { pinned.count < Self.maxPinned }

    /// Puts a tool in the folded dock or takes it out (Início always stays).
    func setPinned(_ pin: Bool, for tab: NotchTab) {
        if pin {
            guard !pinned.contains(tab), canPin else { return }
            pinned.append(tab)
        } else if tab != .home {
            pinned.removeAll { $0 == tab }
        }
        UserDefaults.standard.set(pinned.map(\.rawValue), forKey: Self.pinnedKey)
    }

    // MARK: Dock

    /// The pinned tools the dock shows (a pinned tool switched off in Abas stays off).
    var dockTabs: [NotchTab] { pinned.filter(isVisible) }

    /// What the dock shows, left to right. Folded: the pinned tools and the expand button.
    /// Expanded: the same first, in the same order, then the rest of the tools, the
    /// everyday ones before the Mac's upkeep, each group after a hairline.
    func dockItems(expanded: Bool) -> [NotchDockItem] {
        let rest = visible.filter { !pinned.contains($0) }
        var items = dockTabs.map(NotchDockItem.tab)
        // Nothing left to show: no button to show it.
        guard !rest.isEmpty else { return items }
        items.append(.toggle)
        guard expanded else { return items }
        let groups = [rest.filter { !$0.isCleaning }, rest.filter(\.isCleaning)].filter { !$0.isEmpty }
        for (index, group) in groups.enumerated() {
            items.append(.divider(index))
            items += group.map(NotchDockItem.tab)
        }
        return items
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
