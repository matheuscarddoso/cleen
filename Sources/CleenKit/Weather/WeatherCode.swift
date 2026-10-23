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
        case 0: "Céu limpo"
        case 1: "Predominantemente limpo"
        case 2: "Parcialmente nublado"
        case 3: "Nublado"
        case 45: "Neblina"
        case 48: "Neblina com geada"
        case 51: "Garoa fraca"
        case 53: "Garoa"
        case 55: "Garoa forte"
        case 56: "Garoa congelante fraca"
        case 57: "Garoa congelante"
        case 61: "Chuva fraca"
        case 63: "Chuva"
        case 65: "Chuva forte"
        case 66: "Chuva congelante fraca"
        case 67: "Chuva congelante"
        case 71: "Neve fraca"
        case 73: "Neve"
        case 75: "Neve forte"
        case 77: "Grãos de neve"
        case 80: "Pancadas de chuva fracas"
        case 81: "Pancadas de chuva"
        case 82: "Pancadas de chuva fortes"
        case 85: "Pancadas de neve fracas"
        case 86: "Pancadas de neve"
        case 95: "Trovoada"
        case 96: "Trovoada com granizo"
        case 99: "Trovoada com granizo forte"
        default: "Tempo indefinido"
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
