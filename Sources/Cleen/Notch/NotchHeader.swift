import SwiftUI

/// Sits in the strip beside the camera: what's on screen on the left, controls on the right.
struct NotchHeader: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Text(headerTitle)
                .font(NotchStyle.title)
                .contentTransition(.opacity)
            Spacer()
            if state.tab == .home, !state.showsSettings, !state.mirrorExpanded {
                NotchIconButton(symbol: state.isEditingHome ? "checkmark" : "square.grid.2x2", help: state.isEditingHome ? String(localized: "Concluir") : String(localized: "Editar o Início"), isActive: state.isEditingHome) {
                    withAnimation(.smooth(duration: 0.3)) { state.isEditingHome.toggle() }
                }
            }
            NotchIconButton(symbol: state.isPinned ? "pin.fill" : "pin", help: state.isPinned ? String(localized: "Soltar") : String(localized: "Manter aberto"), isActive: state.isPinned) {
                controller.togglePin()
            }
            NotchIconButton(symbol: state.showsSettings ? "xmark" : "gearshape", help: state.showsSettings ? String(localized: "Fechar ajustes") : String(localized: "Ajustes"), isActive: state.showsSettings) {
                withAnimation(.smooth(duration: 0.25)) { state.showsSettings.toggle() }
            }
        }
    }

    private var headerTitle: String {
        if state.showsSettings { return String(localized: "Ajustes") }
        if state.tab == .home, state.mirrorExpanded { return String(localized: "Espelho") }
        if state.tab == .home, state.isEditingHome { return String(localized: "Editar o Início") }
        return state.tab.title
    }
}
