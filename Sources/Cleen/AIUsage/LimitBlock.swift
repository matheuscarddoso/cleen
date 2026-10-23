import CleenKit
import SwiftUI

/// One limit with room to read: name and percentage on top, the bar with the pace tick,
/// then when it resets and where the pace lands.
struct LimitBlock: View {
    let symbol: String
    let label: String
    let value: String
    let fraction: Double
    var pace: Double?
    var color: Color = NotchStyle.primary
    var detail: String?
    /// A share, not a limit: neutral bar, never the warning colors of a filling quota.
    var isShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchStyle.primary.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(NotchStyle.tertiary)
                        .lineLimit(1)
                }
                Text(value)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
                    .frame(minWidth: 34, alignment: .trailing)
                    .contentTransition(.numericText())
            }
            ZStack {
                UsageBar(fraction: fraction, height: 4, tint: isShare ? NotchStyle.barFill : (color == NotchStyle.primary ? nil : color))
                if let pace { PaceTick(fraction: pace) }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
