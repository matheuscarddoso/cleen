import SwiftUI

/// The dock under the open panel, always one row. Folded, it holds the pinned tools
/// (Início and the Shelf unless the person picks others) and a button that expands it;
/// expanded, the dock itself grows to every tool, up to the panel's width, and scrolls
/// sideways past it. Whether it's expanded is remembered (`TabPreferences.isDockExpanded`),
/// and any tool's context menu pins it to the folded dock or takes it out.
struct NotchTabBar: View {
    /// The widest the dock gets: see `maxWidth(panelWidth:)`.
    let maxWidth: Double

    /// A little narrower than the panel above, by just enough that the dock's round ends
    /// are concentric with the panel's bottom corners: the panel's body is the window
    /// width less its top shoulders, and each end of the dock sits where its centre meets
    /// the centre of the panel's corner (`openBottomRadius - cornerRadius` in).
    static func maxWidth(panelWidth: Double) -> Double {
        let body = panelWidth - NotchStyle.openTopRadius * 2
        return body - max(0, NotchStyle.openBottomRadius - NotchDockLayout.cornerRadius) * 2
    }
    @Environment(NotchState.self) private var state
    @Environment(TabPreferences.self) private var tabs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    /// How far the row is scrolled; with its width, it says which ends have more to
    /// scroll to (those fade out).
    @State private var offset = 0.0

    private var items: [NotchDockItem] { tabs.dockItems(expanded: tabs.isDockExpanded) }

    var body: some View {
        let items = items
        let available = max(NotchDockLayout.buttonWidth, maxWidth - NotchDockLayout.padding * 2)
        let natural = NotchDockLayout.contentWidth(items)
        let scrolls = natural > available
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: NotchDockLayout.spacing) {
                    ForEach(items) { item in
                        cell(item).id(item)
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollDisabled(!scrolls)
            .frame(width: min(natural, available), height: NotchDockLayout.rowHeight)
            .onScrollGeometryChange(for: Double.self) { $0.contentOffset.x } action: { _, offset in
                self.offset = offset
            }
            .mask { fadeMask(leading: scrolls && offset > 1, trailing: scrolls && offset < natural - available - 1) }
            .clipShape(.rect(cornerRadius: NotchDockLayout.innerRadius, style: .continuous))
            // The tool on screen stays in view: when the dock expands or folds, and when
            // the tool changes from elsewhere (the search, a shortcut).
            .onAppear { reveal(state.tab, with: proxy, animated: false) }
            .onChange(of: state.tab) { _, tab in reveal(tab, with: proxy, animated: true) }
            .onChange(of: tabs.isDockExpanded) { reveal(state.tab, with: proxy, animated: true) }
        }
        .padding(NotchDockLayout.padding)
        .background(NotchStyle.background, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.06)) }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .fixedSize()
    }

    @ViewBuilder
    private func cell(_ item: NotchDockItem) -> some View {
        switch item {
        case .tab(let tab):
            tabButton(tab)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
        case .toggle:
            toggle
        case .divider:
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 16)
                .frame(width: NotchDockLayout.dividerWidth)
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    /// Opaque in the middle; at an end with more to scroll to, the row fades out over
    /// `NotchDockLayout.fade`, which says there's more without a scroller.
    private func fadeMask(leading: Bool, trailing: Bool) -> some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: leading ? NotchDockLayout.fade : 0)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: trailing ? NotchDockLayout.fade : 0)
        }
        .animation(.easeOut(duration: 0.15), value: leading)
        .animation(.easeOut(duration: 0.15), value: trailing)
    }

    private func reveal(_ tab: NotchTab, with proxy: ScrollViewProxy, animated: Bool) {
        let item = NotchDockItem.tab(tab)
        guard items.contains(item) else { return }
        if animated, !reduceMotion {
            withAnimation(.smooth(duration: 0.3)) { proxy.scrollTo(item, anchor: .center) }
        } else {
            proxy.scrollTo(item, anchor: .center)
        }
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        NotchTabButton(symbol: tab.symbol, showsClaudeLogo: tab == .agents, title: tab.title, isSelected: state.tab == tab, selection: selection) {
            // Emoji grows the panel like the launcher; switching to or from it animates.
            withAnimation(NotchController.searchResize) { state.tab = tab }
        }
        .contextMenu { pinMenu(tab) }
    }

    @ViewBuilder
    private func pinMenu(_ tab: NotchTab) -> some View {
        if tabs.isPinned(tab) {
            // Início is where the panel opens: it always stays.
            if tab != .home {
                Button("Tirar da barra") { withAnimation(dockAnimation) { tabs.setPinned(false, for: tab) } }
            }
        } else if tabs.canPin {
            Button("Fixar na barra") { withAnimation(dockAnimation) { tabs.setPinned(true, for: tab) } }
        } else {
            Button("A barra já tem \(TabPreferences.maxPinned) ferramentas") {}
                .disabled(true)
        }
    }

    /// Expands the dock or folds it back. Folded, it's lit while the tool on screen is one
    /// the folded dock doesn't show, so the dock always says where the panel is.
    private var toggle: some View {
        let expanded = tabs.isDockExpanded
        let title = expanded ? String(localized: "Recolher a barra") : String(localized: "Mostrar todas as ferramentas")
        return NotchTabButton(symbol: expanded ? "chevron.left" : "square.grid.2x2.fill", title: title, isSelected: !expanded && !tabs.dockTabs.contains(state.tab), selection: selection) {
            withAnimation(dockAnimation) { tabs.isDockExpanded.toggle() }
        }
        .accessibilityValue(expanded ? String(localized: "Expandida") : String(localized: "Recolhida"))
    }

    private var dockAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.86)
    }
}

