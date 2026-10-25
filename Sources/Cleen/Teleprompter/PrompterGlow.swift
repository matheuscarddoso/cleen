import SwiftUI

/// The colored ring around the reading island. It drifts slowly on its own; with the
/// microphone on, the voice drives it: loudness widens and brightens the glow, and each
/// of the four bands (lows to highs) lights its own colors around the ring, so vowels
/// and sibilants move it differently. Behind the panel, so only the outside shows.
struct PrompterGlow<S: Shape>: View {
    let shape: S
    let levels: VoiceLevels
    /// Listening; otherwise the ring just breathes.
    let isListening: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Blue, violet, pink, cyan: one per band, twice around.
    private var hues: [Color] { PrompterGlowPalette.hues }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion && !isListening)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let reading = levels.current
            // Silent or not listening: a slow breath, never fully dark.
            let breath = 0.14 + 0.06 * sin(time * 1.6)
            let level = max(Double(reading.level), reduceMotion ? 0.16 : breath)
            let gradient = AngularGradient(
                stops: stops(bands: reading.bands, level: level),
                center: .center,
                angle: .radians(reduceMotion ? 0 : time * (0.25 + level * 0.9))
            )
            ZStack {
                shape
                    .stroke(gradient, lineWidth: 5 + 16 * level)
                    .blur(radius: 9 + 12 * level)
                    .opacity(0.45 + 0.55 * level)
                shape
                    .stroke(gradient, lineWidth: 1.2 + 2.4 * level)
                    .blur(radius: 1.2)
                    .opacity(0.55 + 0.45 * level)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Eight stops, each band's hue at two opposite places on the ring, lit by that band.
    private func stops(bands: [Float], level: Double) -> [Gradient.Stop] {
        (0..<8).map { index in
            let band = index % 4
            let energy = band < bands.count ? Double(bands[band]) : 0
            let strength = 0.35 + 0.65 * max(energy, level * 0.6)
            return .init(color: hues[band].opacity(strength), location: Double(index) / 8)
        } + [.init(color: hues[0].opacity(0.35 + 0.65 * max(Double(bands.first ?? 0), level * 0.6)), location: 1)]
    }
}

private enum PrompterGlowPalette {
    static let hues: [Color] = [
        Color(red: 0.31, green: 0.49, blue: 1.0),
        Color(red: 0.55, green: 0.36, blue: 1.0),
        Color(red: 1.0, green: 0.37, blue: 0.69),
        Color(red: 0.25, green: 0.82, blue: 1.0),
    ]
}
