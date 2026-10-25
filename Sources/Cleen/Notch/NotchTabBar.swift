import SwiftUI

/// The row of tool icons at the bottom of the panel, in the order set in Ajustes › Abas.
struct NotchTabBar: View {
    @Environment(NotchState.self) private var state
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        // Centered while it fits; with more tools than room it scrolls sideways.
        ViewThatFits(in: .horizontal) {
            buttons
            ScrollView(.horizontal) { buttons.padding(.horizontal, 8) }
                .scrollIndicators(.hidden)
                .scrollEdgeFade(.horizontal, length: 18)
        }
    }

    private var buttons: some View {
        HStack(spacing: 2) {
            ForEach(tabs.visible) { tab in
                NotchTabButton(symbol: tab.symbol, showsClaudeLogo: tab == .agents, title: tab.title, isSelected: state.tab == tab) {
                    // Emoji grows the panel like the launcher; switching to or from it animates.
                    withAnimation(NotchController.searchResize) { state.tab = tab }
                }
            }
        }
    }
}
