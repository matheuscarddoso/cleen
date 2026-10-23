/// A WMO weather interpretation code, as Open-Meteo reports it, with the words and the
/// SF Symbol Cleen shows for it.
///
/// Symbols are the `.fill` variants on purpose: those are the ones with multicolor
/// layers (yellow sun, blue drops), which is how the forecast reads at a glance.
public struct WeatherCode: Hashable, Sendable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    /// "Céu limpo", "Chuva fraca". Sentence case, short enough for a seven-day column's
    /// tooltip and the current-conditions line.
    public var description: String {
        switch rawValue {
        case 0: String(localized: "Céu limpo")
        case 1: String(localized: "Predominantemente limpo")
        case 2: String(localized: "Parcialmente nublado")
        case 3: String(localized: "Nublado")
        case 45: String(localized: "Neblina")
        case 48: String(localized: "Neblina com geada")
        case 51: String(localized: "Garoa fraca")
        case 53: String(localized: "Garoa")
        case 55: String(localized: "Garoa forte")
        case 56: String(localized: "Garoa congelante fraca")
        case 57: String(localized: "Garoa congelante")
        case 61: String(localized: "Chuva fraca")
        case 63: String(localized: "Chuva")
        case 65: String(localized: "Chuva forte")
        case 66: String(localized: "Chuva congelante fraca")
        case 67: String(localized: "Chuva congelante")
        case 71: String(localized: "Neve fraca")
        case 73: String(localized: "Neve")
        case 75: String(localized: "Neve forte")
        case 77: String(localized: "Grãos de neve")
        case 80: String(localized: "Pancadas de chuva fracas")
        case 81: String(localized: "Pancadas de chuva")
        case 82: String(localized: "Pancadas de chuva fortes")
        case 85: String(localized: "Pancadas de neve fracas")
        case 86: String(localized: "Pancadas de neve")
        case 95: String(localized: "Trovoada")
        case 96: String(localized: "Trovoada com granizo")
        case 99: String(localized: "Trovoada com granizo forte")
        default: String(localized: "Tempo indefinido")
        }
    }

    /// The glyph for the sky, with a moon instead of a sun at night where the sky shows.
    public func symbol(isDay: Bool = true) -> String {
        switch rawValue {
        case 0, 1: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55: "cloud.drizzle.fill"
        case 56, 57, 66, 67: "cloud.sleet.fill"
        case 61, 63: "cloud.rain.fill"
        case 65, 82: "cloud.heavyrain.fill"
        case 80, 81: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95: "cloud.bolt.rain.fill"
        case 96, 99: "cloud.hail.fill"
        default: "cloud.fill"
        }
    }
}
