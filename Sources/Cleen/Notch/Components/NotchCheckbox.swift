import SwiftUI

/// A compact round check for notch lists; white when on, with a mixed state for groups.
struct NotchCheckbox: View {
    let state: CheckState
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(state == .off ? NotchStyle.tertiary : .clear, lineWidth: 1.25)
                    .background(state == .off ? .clear : Color.white, in: .circle)
                Image(systemName: state == .mixed ? "minus" : "checkmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.black)
                    .opacity(state == .off ? 0 : 1)
            }
            .frame(width: 15, height: 15)
            .contentShape(.rect)
            .animation(.smooth(duration: 0.15), value: state)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .on ? "selecionado" : state == .mixed ? "parcialmente selecionado" : "não selecionado")
        .accessibilityAddTraits(.isToggle)
    }
}
