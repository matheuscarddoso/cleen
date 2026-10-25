import SwiftUI

/// The light behind the panel while the teleprompter reads: wide, soft color spilling
/// out below it and beside it, over the desktop. Each of four glows along the bottom
/// edge is one band of the voice (lows on the outside, highs in the middle), so vowels
/// and sibilants light it differently; loudness grows and brightens all of it. Silent,
/// or without the microphone, it just breathes.
///
/// It sits behind the black panel, which hides its middle: only the spill shows.
struct PrompterGlow: View {
    let levels: VoiceLevels
    /// Listening; otherwise the glow just breathes.
    let isListening: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Per band, low to high: where along the bottom edge it sits and its color.
    private static let glows: [(x: Double, color: Color)] = [
        (0.08, Color(red: 0.33, green: 0.45, blue: 1.0)),
        (0.36, Color(red: 0.56, green: 0.40, blue: 1.0)),
        (0.64, Color(red: 0.86, green: 0.45, blue: 1.0)),
        (0.92, Color(red: 0.36, green: 0.70, blue: 1.0)),
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion && !isListening)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let reading = levels.current
                let breath = reduceMotion ? 0.18 : 0.16 + 0.06 * sin(time * 1.4)
                let level = max(Double(reading.level), breath)
                let size = proxy.size
                ZStack {
                    wash(level: level, in: size)
                    ForEach(Self.glows.indices, id: \.self) { index in
                        band(index, reading: reading, level: level, time: time, in: size)
                    }
                }
                .blur(radius: 46)
                .frame(width: size.width, height: size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The wash under the whole panel.
    private func wash(level: Double, in size: CGSize) -> some View {
        Ellipse()
            .fill(Color(red: 0.45, green: 0.42, blue: 1.0))
            .frame(width: size.width * (1.05 + 0.15 * level), height: 120 + 110 * level)
            .position(x: size.width / 2, y: size.height - 6)
            .opacity(0.35 + 0.45 * level)
    }

    /// One band's glow, drifting a little along the bottom edge.
    private func band(_ index: Int, reading: VoiceLevels.Reading, level: Double, time: TimeInterval, in size: CGSize) -> some View {
        let glow = Self.glows[index]
        let energy = index < reading.bands.count ? Double(reading.bands[index]) : 0
        let lit = max(energy, level * 0.5)
        let phase = time * (0.5 + Double(index) * 0.17) + Double(index) * 1.7
        let drift = reduceMotion ? 0 : sin(phase) * 18
        return Ellipse()
            .fill(glow.color)
            .frame(width: 170 + 170 * lit, height: 90 + 120 * lit)
            .position(x: size.width * glow.x + drift, y: size.height - 4)
            .opacity(0.3 + 0.7 * lit)
    }
}
