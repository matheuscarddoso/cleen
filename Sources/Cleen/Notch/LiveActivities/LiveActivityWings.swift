import SwiftUI

/// A banner across both wings: what happened on the left of the camera, the detail on
/// the right. Shown for a few seconds by `LiveActivityCenter`.
struct LiveActivityBanner: View {
    let activity: LiveActivity
    let notchWidth: Double
    let inset: Double
    let artworkSize: Double
    @Environment(NowPlayingModel.self) private var nowPlaying

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) { leading }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, inset)
            Spacer(minLength: notchWidth)
            trailing
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, inset + 2)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .power(let power, let level):
            Image(systemName: Self.batterySymbol(power, level: level))
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Self.batteryColor(power), NotchStyle.secondary)
            label(Self.powerTitle(power))
        case .headphones(let name, let connected):
            Image(systemName: Self.headphonesSymbol(name))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(connected ? NotchStyle.primary : NotchStyle.secondary)
            label(Self.shortName(name))
        case .track(let title, _):
            WingArtwork(image: nowPlaying.artwork, size: artworkSize, cornerRadius: max(3, NotchStyle.closedBottomRadius - inset))
            label(title)
        case .meeting(let title, _, let color):
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: color))
            label(title)
        case .timerEnded(let phase):
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.warning)
            label(phase)
        case .copied(let text, let color):
            if let color {
                Circle()
                    .fill(Color(nsColor: color))
                    .frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(Color.white.opacity(0.3)) }
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
            }
            label(text)
        case .notice(let title, _, let symbol):
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
            label(title)
        case .downloaded(let url, _):
            // Drawn as an island (`DownloadIsland`); this is the fallback.
            label(url.lastPathComponent)
        case .message(let message):
            label(message.text)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .power(let power, let level):
            Text(level.percent)
                .foregroundStyle(Self.batteryColor(power))
        case .headphones(_, let connected):
            Text(connected ? String(localized: "Conectado") : String(localized: "Desconectado"))
                .foregroundStyle(connected ? NotchStyle.good : NotchStyle.secondary)
        case .track(_, let artist):
            Text(artist)
                .foregroundStyle(NotchStyle.secondary)
        case .meeting(_, let start, _):
            Text(MeetingCountdown.text(until: start))
                .foregroundStyle(NotchStyle.primary)
        case .timerEnded:
            Text("Concluído")
                .foregroundStyle(NotchStyle.warning)
        case .copied:
            Text("Copiado")
                .foregroundStyle(NotchStyle.good)
        case .notice(_, let detail, _):
            Text(detail)
                .foregroundStyle(NotchStyle.secondary)
        case .downloaded:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(NotchStyle.good)
        case .message:
            Text("agora").foregroundStyle(NotchStyle.secondary)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NotchStyle.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    static func powerTitle(_ power: LiveActivity.Power) -> String {
        switch power {
        case .charging: String(localized: "Carregando")
        case .unplugged: String(localized: "Na bateria")
        case .full: String(localized: "Carga completa")
        case .low: String(localized: "Bateria fraca")
        }
    }

    static func batteryColor(_ power: LiveActivity.Power) -> Color {
        switch power {
        case .charging, .full: NotchStyle.good
        case .unplugged: NotchStyle.primary
        case .low: NotchStyle.critical
        }
    }

    static func batterySymbol(_ power: LiveActivity.Power, level: Double) -> String {
        if power == .charging || power == .full { return "battery.100percent.bolt" }
        switch level {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    static func headphonesSymbol(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpods.max" }
        if lower.contains("airpods pro") { return "airpods.pro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        return "headphones"
    }

    /// "AirPods Pro de Matheus" → "AirPods Pro": the owner's name says nothing here.
    static func shortName(_ name: String) -> String {
        for separator in [" de ", "’s ", "'s "] {
            if let range = name.range(of: separator) {
                return separator == " de " ? String(name[..<range.lowerBound]) : String(name[range.upperBound...])
            }
        }
        return name
    }
}

/// "12 min", "agora": how soon a meeting starts.
enum MeetingCountdown {
    static func text(until start: Date, now: Date = .now) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes <= 0 ? String(localized: "agora") : String(localized: "\(minutes) min")
    }
}
