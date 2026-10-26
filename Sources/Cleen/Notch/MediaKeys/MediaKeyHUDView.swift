import CleenKit
import SwiftUI

/// The volume or brightness level across the closed notch's wings, Droppy style: the
/// symbol and its name on the left of the camera, a short colored bar and the number
/// (rolling as it changes) on the right.
struct MediaKeyHUDWings: View {
    let reading: MediaKeyHUD.Reading
    let notchWidth: Double
    let notchHeight: Double

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                MediaKeyHUDSymbol(reading: reading)
                MediaKeyHUDName(reading: reading)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, inset + 3)
            Spacer(minLength: notchWidth)
            MediaKeyHUDLevel(reading: reading, barWidth: 40)
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
            MediaKeyHUDName(reading: reading)
            MediaKeyHUDLevel(reading: reading, barWidth: 72)
                .padding(.leading, 6)
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

/// "Volume" or "Tela", the way Droppy names what's changing.
struct MediaKeyHUDName: View {
    let reading: MediaKeyHUD.Reading

    var body: some View {
        Text(reading.kind == .volume ? "Volume" : "Tela")
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(reading.isSilent ? NotchStyle.secondary : NotchStyle.primary)
            .lineLimit(1)
            .fixedSize()
            .contentTransition(.opacity)
    }
}

/// A thin bar with the number after it, sized for "100 %" so neither moves as the
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
                            .fill(reading.isSilent ? NotchStyle.tertiary : tint)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(width: barWidth, height: 5)
                .clipShape(Capsule())
            // Sized for "100" so nothing moves as the digits roll.
            ZStack(alignment: .trailing) {
                Text(verbatim: "100").hidden()
                Text(verbatim: "\(Int((fraction * 100).rounded()))")
                    .foregroundStyle(reading.isSilent ? NotchStyle.secondary : NotchStyle.primary)
                    .contentTransition(.numericText(value: reading.level))
            }
            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: reading.level)
        .animation(.smooth(duration: 0.2), value: reading.isSilent)
        .accessibilityValue(Text(verbatim: reading.level.percent))
    }

    private var fraction: Double { min(1, max(0, reading.level)) }

    /// Green for sound, yellow for light, as Droppy colors them.
    private var tint: Color {
        reading.kind == .volume ? Color(red: 0.3, green: 0.85, blue: 0.5) : Color(red: 1, green: 0.8, blue: 0.1)
    }
}
