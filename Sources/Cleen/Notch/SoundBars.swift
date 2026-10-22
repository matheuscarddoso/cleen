import SwiftUI

/// Four bars bouncing out of phase, the "something is playing" glyph.
struct SoundBars: View {
    var tint = Color.white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(tint)
                        .frame(width: 2.5, height: Self.height(index: index, time: time))
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }

    /// Two sines per bar at unrelated speeds, so the motion never looks like a loop.
    static func height(index: Int, time: TimeInterval) -> Double {
        let speeds = [5.1, 6.7, 4.3, 7.4]
        let offsets = [0.0, 1.3, 2.6, 0.7]
        let wave = sin(time * speeds[index] + offsets[index]) * 0.6 + sin(time * speeds[index] * 0.47 + offsets[index] * 2) * 0.4
        return 4 + (wave + 1) / 2 * 10
    }
}
