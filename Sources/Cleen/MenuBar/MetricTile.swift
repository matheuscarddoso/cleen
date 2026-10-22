import SwiftUI

/// One vital in the panel: label, big value, a line of context and its recent history.
struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    var detailColor: Color?
    var history: [Double] = []
    var maximum: Double?
    var tint = Theme.accent
    /// Shown where the sparkline would be, for metrics without a history.
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(Theme.eyebrow)
                .tracking(0.8)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Theme.display(21))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(detail)
                .font(Theme.caption)
                .foregroundStyle(detailColor ?? .secondary)
                .lineLimit(1)
            if let footnote {
                Text(footnote)
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(height: 22, alignment: .bottomLeading)
            } else {
                Sparkline(values: history, tint: tint, maximum: maximum)
                    .frame(height: 22)
                    .opacity(history.isEmpty ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(radius: Theme.Radius.medium, padding: 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value, detail, footnote].compactMap { $0 }.joined(separator: ", "))
    }
}
