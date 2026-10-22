import SwiftUI

/// A round selection mark with a mixed state for groups. Calls `action` to toggle;
/// the owner decides what toggling a mixed group means.
struct Checkbox: View {
    let state: CheckState
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(state == .off ? Color.white.opacity(0.28) : .clear, lineWidth: 1.25)
                    .background(state == .off ? .clear : Theme.accent, in: .circle)
                Image(systemName: state == .mixed ? "minus" : "checkmark")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .opacity(state == .off ? 0 : 1)
            }
            .frame(width: 17, height: 17)
            .contentShape(.rect)
            .animation(Theme.quick, value: state)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .on ? "selecionado" : state == .mixed ? "parcialmente selecionado" : "não selecionado")
        .accessibilityAddTraits(.isToggle)
    }
}
