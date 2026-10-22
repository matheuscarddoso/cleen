import SwiftUI

/// The row of tool icons at the bottom of the panel, then the sections that only make
/// sense in a full window.
struct NotchTabBar: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(spacing: 2) {
            ForEach(NotchTab.allCases) { tab in
                NotchTabButton(symbol: tab.symbol, title: tab.title, isSelected: state.tab == tab) {
                    state.tab = tab
                }
            }
            Rectangle()
                .fill(NotchStyle.track)
                .frame(width: 1, height: 14)
                .padding(.horizontal, 6)
            ForEach([Route.spaceLens, .duplicates, .uninstaller, .leftovers]) { route in
                NotchTabButton(symbol: route.symbol, title: "\(route.title) (janela)", isSelected: false) {
                    controller.openWindow(route)
                }
            }
        }
    }
}
