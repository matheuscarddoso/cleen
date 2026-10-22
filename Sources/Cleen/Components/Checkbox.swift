import SwiftUI

/// A macOS-style checkbox with a mixed state for groups. Calls `action` to toggle;
/// the owner decides what toggling a mixed group means.
struct Checkbox: View {
    let state: CheckState
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(state == .off ? AnyShapeStyle(Theme.surface) : AnyShapeStyle(Theme.accent))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(state == .off ? Color.primary.opacity(0.25) : .clear, lineWidth: 1)
                Image(systemName: state == .mixed ? "minus" : "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(state == .off ? 0 : 1)
            }
            .frame(width: 15, height: 15)
            .contentShape(.rect)
            .animation(Theme.quick, value: state)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .on ? "selecionado" : state == .mixed ? "parcialmente selecionado" : "não selecionado")
        .accessibilityAddTraits(.isToggle)
    }
}
