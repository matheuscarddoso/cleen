import SwiftUI

/// − value + over a fixed list of choices, for options too long for segments.
struct NotchChoiceStepper<Value: Equatable>: View {
    let choices: [Value]
    @Binding var selection: Value
    let format: (Value) -> String

    var body: some View {
        let index = choices.firstIndex(of: selection) ?? 0
        HStack(spacing: 0) {
            button("minus", label: String(localized: "Menor")) { selection = choices[max(0, index - 1)] }
                .disabled(index == 0)
            Text(format(selection))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .frame(minWidth: 60)
                .contentTransition(.numericText())
            button("plus", label: String(localized: "Maior")) { selection = choices[min(choices.count - 1, index + 1)] }
                .disabled(index == choices.count - 1)
        }
        .frame(height: 24)
        .background(NotchStyle.control, in: .capsule)
        .animation(.smooth(duration: 0.15), value: index)
    }

    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .bold))
                .frame(width: 26, height: 24)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
