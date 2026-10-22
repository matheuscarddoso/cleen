import SwiftUI

/// A thin circular gauge. The arc starts at 12 o'clock and fills clockwise.
struct RingGauge: View {
    /// 0...1
    let value: Double
    var tint = Theme.accent
    var lineWidth = 6.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.standard, value: value)
        }
        .padding(lineWidth / 2)
        .accessibilityElement()
        .accessibilityValue(value.percent)
    }
}
