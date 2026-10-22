import SwiftUI

/// A usage ring with a glyph in the middle, colored by how full it is.
struct NotchRing: View {
    let fraction: Double
    let symbol: String
    var lineWidth = 6.0

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.01, min(1, fraction)))
                .stroke(NotchStyle.level(fraction), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.4), value: fraction)
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
        }
        .padding(lineWidth / 2)
        .accessibilityElement()
        .accessibilityValue(fraction.percent)
    }
}
