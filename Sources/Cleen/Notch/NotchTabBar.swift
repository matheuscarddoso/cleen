import SwiftUI

/// The tools as a dock floating under the open panel: a black capsule of icons, in the
/// order set in Ajustes › Abas, the open one on a light pill that slides to the next.
struct NotchTabBar: View {
    /// No wider than the panel above; more tools than that scroll sideways.
    let maxWidth: Double
    @Environment(NotchState.self) private var state
    @Environment(TabPreferences.self) private var tabs
    @Namespace private var selection

    var body: some View {
        let natural = Double(tabs.visible.count) * (NotchTabButton.width + 1) - 1 + 8
        // A dock, not a bar: narrower than the panel, scrolling when the tools don't fit.
        let room = maxWidth - 160
        Group {
            if natural <= room {
                buttons.padding(4)
            } else {
                ScrollViewReader { reader in
                    ScrollView(.horizontal) { buttons.padding(4) }
                        // The open tool is always in view, even at the far end.
                        .onAppear { reader.scrollTo(state.tab, anchor: .center) }
                        .onChange(of: state.tab) { _, tab in
                            withAnimation(.smooth(duration: 0.3)) { reader.scrollTo(tab, anchor: .center) }
                        }
                }
                    .scrollIndicators(.never)
                    .scrollEdgeFade(.horizontal, length: 22)
                    .clipShape(.capsule)
            }
        }
        .frame(width: min(natural, room), height: NotchGeometry.dockHeight)
        .background(NotchStyle.background, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.06)) }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private var buttons: some View {
        HStack(spacing: 1) {
            ForEach(tabs.visible) { tab in
                NotchTabButton(symbol: tab.symbol, showsClaudeLogo: tab == .agents, title: tab.title, isSelected: state.tab == tab, selection: selection) {
                    // Emoji grows the panel like the launcher; switching to or from it animates.
                    withAnimation(NotchController.searchResize) { state.tab = tab }
                }
                .id(tab)
            }
        }
    }
}
