import SwiftUI

/// Fills the notch panel window. The black shape hangs from the top center and morphs
/// between the closed notch (with its live-activity wings) and the open panel.
struct NotchRootView: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state
    @AppStorage(NotchSettings.showsWingsKey) private var showsWings = true

    var body: some View {
        if let geometry = state.geometry {
            let size = state.isOpen ? geometry.openSize : geometry.closedSize(showsWings: showsWings)
            let topRadius = state.isOpen ? NotchStyle.openTopRadius : NotchStyle.closedTopRadius
            let bottomRadius = state.isOpen ? NotchStyle.openBottomRadius : NotchStyle.closedBottomRadius

            ZStack(alignment: .top) {
                NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                    .fill(NotchStyle.background)
                    .shadow(color: .black.opacity(state.isOpen ? 0.55 : 0), radius: 22, y: 10)

                Group {
                    if state.isOpen {
                        NotchOpenContent(controller: controller, notchHeight: geometry.notchSize.height)
                            .transition(.opacity.combined(with: .scale(0.96, anchor: .top)).combined(with: .blurReplace))
                    } else if showsWings {
                        NotchWings(notchWidth: geometry.notchSize.width)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, topRadius)
                .clipShape(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        }
    }
}
