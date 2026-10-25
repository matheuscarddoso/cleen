import SwiftUI

/// The arc of light behind the script while it reads: a dome rising from the middle of
/// the panel's bottom edge, brightest along its rim. Your voice drives it: loudness
/// lifts and brightens it, and where the voice sits tints it (deeper violet on the lows,
/// toward cyan on the highs). Silent, or without the microphone, it just breathes.
struct PrompterArc: View {
    let levels: VoiceLevels
    /// Listening; otherwise the arc just breathes.
    let isListening: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !isListening && reduceMotion)) { context in
                let reading = levels.current
                let time = context.date.timeIntervalSinceReferenceDate
                let breath = reduceMotion ? 0.12 : 0.1 + 0.05 * sin(time * 1.5)
                let level = max(Double(reading.level), breath)
                let radius = min(proxy.size.height * 0.95, 58 + 92 * level)
                let rim = tint(bands: reading.bands)
                Ellipse()
                    .fill(
                        EllipticalGradient(
                            stops: [
                                .init(color: rim.opacity(0.18 + 0.22 * level), location: 0),
                                .init(color: rim.opacity(0.35 + 0.45 * level), location: 0.62),
                                .init(color: rim.opacity(0.55 + 0.45 * level), location: 0.8),
                                .init(color: rim.opacity(0), location: 1),
                            ],
                            center: .center,
                            startRadiusFraction: 0,
                            endRadiusFraction: 0.5
                        )
                    )
                    .frame(width: radius * 2.6, height: radius * 2)
                    .blur(radius: 6)
                    .position(x: proxy.size.width / 2, y: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Blue, pulled toward violet by the lows and toward cyan by the highs.
    private func tint(bands: [Float]) -> Color {
        let lows = Double(bands.prefix(2).reduce(0, +)) / 2
        let highs = Double(bands.suffix(2).reduce(0, +)) / 2
        let lean = max(-1, min(1, (highs - lows) * 2))
        let violet = (0.48, 0.36, 1.0), blue = (0.24, 0.42, 1.0), cyan = (0.2, 0.78, 1.0)
        let (from, to, amount) = lean < 0 ? (blue, violet, -lean) : (blue, cyan, lean)
        return Color(
            red: from.0 + (to.0 - from.0) * amount,
            green: from.1 + (to.1 - from.1) * amount,
            blue: from.2 + (to.2 - from.2) * amount
        )
    }
}
