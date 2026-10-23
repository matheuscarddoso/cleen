import SwiftUI

/// The widgets' gauge: a track and a rounded arc that fills clockwise from the top,
/// with whatever the widget wants in the middle.
struct HomeRing<Center: View>: View {
    let fraction: Double
    var color: Color = NotchStyle.barFill
    var lineWidth = 6.0
    @ViewBuilder let center: Center

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.015, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.4), value: fraction)
    }
}
