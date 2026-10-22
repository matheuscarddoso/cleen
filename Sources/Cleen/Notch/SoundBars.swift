import SwiftUI

/// The "something is playing" glyph: four bars breathing out of phase.
///
/// Drawn in a Canvas with every edge snapped to the display's pixel grid, so it stays
/// crisp on a 1× external monitor as well as on Retina (fractional widths and heights
/// are what made the bars blur and shimmer there).
struct SoundBars: View {
    var tint = Color.white
    var isPlaying = true
    @Environment(\.displayScale) private var scale

    private static let barCount = 4
    private static let barWidth = 3.0
    private static let spacing = 2.0
    private static let maxHeight = 14.0
    private static let minHeight = 3.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let pixel = 1 / max(scale, 1)
                for index in 0..<Self.barCount {
                    let level = isPlaying ? Self.level(index: index, time: time) : 0
                    let raw = Self.minHeight + (Self.maxHeight - Self.minHeight) * level
                    let height = (raw / pixel).rounded() * pixel
                    let x = ((Double(index) * (Self.barWidth + Self.spacing)) / pixel).rounded() * pixel
                    let y = (((size.height - height) / 2) / pixel).rounded() * pixel
                    let bar = CGRect(x: x, y: y, width: Self.barWidth, height: height)
                    canvas.fill(Path(roundedRect: bar, cornerRadius: Self.barWidth / 2), with: .color(tint))
                }
            }
        }
        .frame(
            width: Double(Self.barCount) * Self.barWidth + Double(Self.barCount - 1) * Self.spacing,
            height: Self.maxHeight
        )
        .accessibilityHidden(true)
    }

    /// 0...1. Two slow sines per bar at unrelated rates, eased so bars linger near the
    /// top and bottom instead of ticking through the middle.
    static func level(index: Int, time: TimeInterval) -> Double {
        let rates = [2.1, 2.9, 1.7, 2.5]
        let phases = [0.0, 1.9, 3.7, 0.9]
        let a = sin(time * rates[index] + phases[index])
        let b = sin(time * rates[index] * 0.61 + phases[index] * 1.7)
        let mixed = (a * 0.65 + b * 0.35 + 1) / 2
        // Smoothstep: softer turns at the extremes.
        return mixed * mixed * (3 - 2 * mixed)
    }
}
