import SwiftUI

/// One vital: label, value, context, and a usage bar or a recent-history line.
struct NotchMetricCard: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String
    var detailColor: Color?
    var fraction: Double?
    var fractionTint: Color?
    var history: [Double] = []
    var maximum: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            if let fraction {
                UsageBar(fraction: fraction, height: 4, tint: fractionTint)
            }
            Text(detail)
                .font(NotchStyle.caption)
                .foregroundStyle(detailColor ?? NotchStyle.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if !history.isEmpty {
                Sparkline(values: history, tint: .white, maximum: maximum)
                    .frame(height: 18)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .notchCard(padding: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value), \(detail)")
    }
}
