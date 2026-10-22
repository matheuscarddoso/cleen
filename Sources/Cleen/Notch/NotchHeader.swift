import SwiftUI

/// Sits in the strip beside the camera: what's on screen on the left, controls on the right.
struct NotchHeader: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Text(state.showsSettings ? "Ajustes" : state.tab.title)
                .font(NotchStyle.title)
                .contentTransition(.opacity)
            Spacer()
            NotchIconButton(symbol: state.isPinned ? "pin.fill" : "pin", help: state.isPinned ? "Soltar" : "Manter aberto", isActive: state.isPinned) {
                controller.togglePin()
            }
            NotchIconButton(symbol: state.showsSettings ? "xmark" : "gearshape", help: state.showsSettings ? "Fechar ajustes" : "Ajustes", isActive: state.showsSettings) {
                withAnimation(.smooth(duration: 0.25)) { state.showsSettings.toggle() }
            }
        }
    }
}
