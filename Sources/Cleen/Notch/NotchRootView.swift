import SwiftUI

/// Fills the notch panel window. The black shape hangs from the top center and morphs
/// between the closed notch (with its live-activity wings) and the open panel.
struct NotchRootView: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state
    @AppStorage(NotchSettings.showsWingsKey) private var showsWings = true

    var body: some View {
        if let geometry = state.geometry {
            let closed = geometry.closedSize(showsWings: showsWings)
            let size = state.isOpen ? geometry.openSize : closed
            let shape = NotchShape(
                topRadius: state.isOpen ? NotchStyle.openTopRadius : NotchStyle.closedTopRadius,
                bottomRadius: state.isOpen ? NotchStyle.openBottomRadius : NotchStyle.closedBottomRadius
            )

            ZStack(alignment: .top) {
                // Content is laid out at its final size, never squeezed by the moving
                // shape: the shape only reveals and hides it.
                if state.isOpen {
                    NotchOpenContent(controller: controller, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.openTopRadius)
                        .frame(width: geometry.openSize.width, height: geometry.openSize.height, alignment: .top)
                        .transition(.notchPanel)
                } else if showsWings {
                    NotchWings(notchWidth: geometry.notchSize.width, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.closedTopRadius)
                        .frame(width: closed.width, height: closed.height)
                        .transition(.notchWings)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(NotchStyle.background)
            .clipShape(shape)
            .background {
                shape
                    .fill(NotchStyle.background)
                    .shadow(color: .black.opacity(state.isOpen ? 0.55 : 0), radius: 22, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        }
    }
}
