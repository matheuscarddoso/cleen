import SwiftUI

/// The time left as an arc that empties toward the top, like the Clock app's timer.
/// While running it sweeps linearly between the once-a-second updates, so it moves
/// continuously instead of in steps.
struct TimerRing<Center: View>: View {
    /// Share of the phase still left, 1 → 0.
    let remaining: Double
    var color: Color = NotchStyle.barFill
    var lineWidth = 6.0
    var isRunning = false
    @ViewBuilder let center: Center

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, remaining)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(isRunning ? .linear(duration: 1) : .smooth(duration: 0.4), value: remaining)
                .animation(.smooth(duration: 0.3), value: color)
            center
        }
        .padding(lineWidth / 2)
    }
}
