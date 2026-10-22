import SwiftUI

/// Sits in the strip beside the camera: tool name on the left, panel controls on the right.
struct NotchHeader: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Text(state.tab.title)
                .font(NotchStyle.title)
                .contentTransition(.opacity)
            Spacer()
            NotchIconButton(symbol: "macwindow", help: "Abrir na janela") {
                controller.openWindow(state.tab.route)
            }
            NotchIconButton(symbol: state.isPinned ? "pin.fill" : "pin", help: state.isPinned ? "Soltar" : "Manter aberto", isActive: state.isPinned) {
                controller.togglePin()
            }
            NotchIconButton(symbol: "gearshape", help: "Ajustes") {
                controller.openWindow(.settings)
            }
        }
    }
}
