import SwiftUI

/// − value + in one pill.
struct NotchStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let format: (Int) -> String

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", label: "Diminuir") { value = max(range.lowerBound, value - step) }
                .disabled(value <= range.lowerBound)
            Text(format(value))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            stepButton("plus", label: "Aumentar") { value = min(range.upperBound, value + step) }
                .disabled(value >= range.upperBound)
        }
        .frame(height: 24)
        .background(NotchStyle.control, in: .capsule)
        .animation(.smooth(duration: 0.15), value: value)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
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
