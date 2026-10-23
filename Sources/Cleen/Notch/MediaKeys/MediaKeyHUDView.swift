import CleenKit
import SwiftUI

/// The volume or brightness level across the closed notch's wings, NotchNook style:
/// the symbol on the left of the camera, a thin bar and the percentage on the right.
struct MediaKeyHUDWings: View {
    let reading: MediaKeyHUD.Reading
    let notchWidth: Double
    let notchHeight: Double

    var body: some View {
        HStack(spacing: 0) {
            MediaKeyHUDSymbol(reading: reading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, inset + 1)
            Spacer(minLength: notchWidth)
            MediaKeyHUDLevel(reading: reading, barWidth: 48)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, inset + 2)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The same gap from the sides as the other wings keep from the bottom.
    private var inset: Double { (notchHeight - min(20, notchHeight - 8)) / 2 }
}

/// While the panel is open the wings aren't there: the level floats as a small pill
/// just under the camera, over the top of the tool.
struct MediaKeyHUDPill: View {
    let reading: MediaKeyHUD.Reading

    var body: some View {
        HStack(spacing: 9) {
            MediaKeyHUDSymbol(reading: reading)
            MediaKeyHUDLevel(reading: reading, barWidth: 96)
        }
        .padding(.leading, 11)
        .padding(.trailing, 12)
        .frame(height: 28)
        .background(Capsule().fill(Color(white: 0.09)))
        .overlay(Capsule().strokeBorder(NotchStyle.cardStroke))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// Speaker or sun, following the level: the speaker's waves fill in as the volume
/// rises (and it shows the slash when silent), the sun grows its rays past half.
struct MediaKeyHUDSymbol: View {
    let reading: MediaKeyHUD.Reading

    var body: some View {
        Image(systemName: symbol, variableValue: reading.kind == .volume && !reading.isSilent ? max(0.01, reading.level) : nil)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(reading.isSilent ? NotchStyle.secondary : NotchStyle.primary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 18, alignment: .leading)
            .accessibilityLabel(reading.kind == .volume ? Text("Volume") : Text("Brilho"))
    }

    private var symbol: String {
        switch reading.kind {
        case .volume: reading.isSilent ? "speaker.slash.fill" : "speaker.wave.3.fill"
        case .brightness: reading.level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }
}

/// A thin bar with the percentage after it, sized for "100 %" so neither moves as the
/// digits change.
struct MediaKeyHUDLevel: View {
    let reading: MediaKeyHUD.Reading
    let barWidth: Double

    var body: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(NotchStyle.track)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(reading.isSilent ? NotchStyle.tertiary : NotchStyle.primary)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(width: barWidth, height: 4)
                .clipShape(Capsule())
            ZStack(alignment: .trailing) {
                Text(verbatim: 1.0.percent).hidden()
                Text(verbatim: reading.level.percent)
                    .foregroundStyle(reading.isSilent ? NotchStyle.secondary : NotchStyle.primary)
                    .contentTransition(.numericText(value: reading.level))
            }
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: reading.level)
        .animation(.smooth(duration: 0.2), value: reading.isSilent)
        .accessibilityValue(Text(verbatim: reading.level.percent))
    }

    private var fraction: Double { min(1, max(0, reading.level)) }
}
