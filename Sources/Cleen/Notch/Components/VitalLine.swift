import SwiftUI

/// "CPU ······ 19%" with a usage bar underneath.
struct VitalLine: View {
    let label: String
    let value: String
    let fraction: Double
    var tint: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
                Spacer()
                Text(value)
                    .font(NotchStyle.captionMedium.monospacedDigit())
                    .contentTransition(.numericText())
            }
            UsageBar(fraction: fraction, height: 3.5, tint: tint)
        }
        .accessibilityElement(children: .combine)
    }
}
