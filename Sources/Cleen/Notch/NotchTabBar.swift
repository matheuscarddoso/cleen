import SwiftUI

/// The dock under the open panel, Droppy's: a few tools (Início and the Shelf unless the
/// person pinned others) and a grid button that shows every tool.
struct NotchTabBar: View {
    /// No wider than the panel above.
    let maxWidth: Double
    @Environment(NotchState.self) private var state
    @Environment(TabPreferences.self) private var tabs
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 1) {
            ForEach(tabs.pinned) { tab in
                NotchTabButton(symbol: tab.symbol, showsClaudeLogo: tab == .agents, title: tab.title, isSelected: !state.showsAllTools && state.tab == tab, selection: selection) {
                    // Emoji grows the panel like the launcher; switching to or from it animates.
                    withAnimation(NotchController.searchResize) {
                        state.tab = tab
                        state.showsAllTools = false
                    }
                }
            }
            // The grid: lit while it's open, or while a tool from it is.
            NotchTabButton(symbol: "square.grid.2x2.fill", title: String(localized: "Todas as ferramentas"), isSelected: state.showsAllTools || !tabs.pinned.contains(state.tab), selection: selection) {
                withAnimation(NotchController.searchResize) { state.showsAllTools.toggle() }
            }
        }
        .padding(4)
        .frame(height: NotchGeometry.dockHeight)
        .background(NotchStyle.background, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.06)) }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .frame(maxWidth: maxWidth)
        .fixedSize()
    }
}
