import SwiftUI

struct LiveChartCard: View {
    let title: String
    let value: String
    let detail: String
    let history: [Double]
    let maximum: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.eyebrow)
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Theme.display(28))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(detail)
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Sparkline(values: history, maximum: maximum)
                .frame(height: 56)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(padding: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value), \(detail)")
    }
}
