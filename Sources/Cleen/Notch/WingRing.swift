import SwiftUI

/// A tiny disk-fullness ring for the closed notch.
struct WingRing: View {
    let fraction: Double
    /// Defaults to the usage colors (white, orange, red as it fills).
    var color: Color?

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.track, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(color ?? NotchStyle.level(fraction), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
        .accessibilityLabel("Indicador")
        .accessibilityValue(fraction.percent)
    }
}
