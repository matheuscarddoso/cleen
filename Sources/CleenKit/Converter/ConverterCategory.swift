import Foundation

/// What the converter converts. Physical quantities go through Foundation's
/// `Measurement`; money goes through the day's exchange rates.
public enum ConverterCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case length
    case mass
    case temperature
    case volume
    case speed
    case area
    case data
    case time
    case currency

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .length: String(localized: "Comprimento")
        case .mass: String(localized: "Massa")
        case .temperature: String(localized: "Temperatura")
        case .volume: String(localized: "Volume")
        case .speed: String(localized: "Velocidade")
        case .area: String(localized: "Área")
        case .data: String(localized: "Dados")
        case .time: String(localized: "Tempo")
        case .currency: String(localized: "Moeda")
        }
    }

    /// The units on offer, in the order the picker lists them. Currencies come from the
    /// rates instead (see `CurrencyRates.units`).
    public var units: [ConverterUnit] {
        switch self {
        case .length: [
            .init("mm", String(localized: "Milímetros"), "mm"), .init("cm", String(localized: "Centímetros"), "cm"), .init("m", String(localized: "Metros"), "m"),
            .init("km", String(localized: "Quilômetros"), "km"), .init("in", String(localized: "Polegadas"), "pol"), .init("ft", String(localized: "Pés"), String(localized: "pés")),
            .init("yd", String(localized: "Jardas"), "jd"), .init("mi", String(localized: "Milhas"), "mi"), .init("nmi", String(localized: "Milhas náuticas"), "mn"),
        ]
        case .mass: [
            .init("mg", String(localized: "Miligramas"), "mg"), .init("g", String(localized: "Gramas"), "g"), .init("kg", String(localized: "Quilos"), "kg"),
            .init("t", String(localized: "Toneladas"), "t"), .init("oz", String(localized: "Onças"), "oz"), .init("lb", String(localized: "Libras"), "lb"),
            .init("st", String(localized: "Stones"), "st"),
        ]
        case .temperature: [
            .init("c", String(localized: "Celsius"), "°C"), .init("f", String(localized: "Fahrenheit"), "°F"), .init("k", String(localized: "Kelvin"), "K"),
        ]
        case .volume: [
            .init("ml", String(localized: "Mililitros"), "ml"), .init("l", String(localized: "Litros"), "l"), .init("m3", String(localized: "Metros cúbicos"), "m³"),
            .init("tsp", String(localized: "Colheres de chá"), String(localized: "c. chá")), .init("tbsp", String(localized: "Colheres de sopa"), String(localized: "c. sopa")),
            .init("cup", String(localized: "Xícaras"), "xíc."), .init("floz", String(localized: "Onças líquidas"), "fl oz"),
            .init("gal", String(localized: "Galões (EUA)"), "gal"), .init("galuk", String(localized: "Galões (RU)"), String(localized: "gal RU")),
        ]
        case .speed: [
            .init("mps", String(localized: "Metros por segundo"), "m/s"), .init("kmh", String(localized: "Quilômetros por hora"), "km/h"),
            .init("mph", String(localized: "Milhas por hora"), "mph"), .init("kn", String(localized: "Nós"), String(localized: "nós")),
        ]
        case .area: [
            .init("cm2", String(localized: "Centímetros quadrados"), "cm²"), .init("m2", String(localized: "Metros quadrados"), "m²"),
            .init("ha", String(localized: "Hectares"), "ha"), .init("km2", String(localized: "Quilômetros quadrados"), "km²"),
            .init("ft2", String(localized: "Pés quadrados"), String(localized: "pés²")), .init("ac", String(localized: "Acres"), "ac"), .init("mi2", String(localized: "Milhas quadradas"), "mi²"),
        ]
        case .data: [
            .init("bit", String(localized: "Bits"), "bit"), .init("B", String(localized: "Bytes"), "B"), .init("KB", String(localized: "Kilobytes"), "KB"),
            .init("MB", String(localized: "Megabytes"), "MB"), .init("GB", String(localized: "Gigabytes"), "GB"), .init("TB", String(localized: "Terabytes"), "TB"),
            .init("PB", String(localized: "Petabytes"), "PB"), .init("MiB", String(localized: "Mebibytes"), "MiB"), .init("GiB", String(localized: "Gibibytes"), "GiB"),
        ]
        case .time: [
            .init("ms", String(localized: "Milissegundos"), "ms"), .init("s", String(localized: "Segundos"), "s"), .init("min", String(localized: "Minutos"), "min"),
            .init("h", String(localized: "Horas"), "h"), .init("d", String(localized: "Dias"), "d"), .init("wk", String(localized: "Semanas"), "sem"), .init("yr", String(localized: "Anos"), "anos"),
        ]
        case .currency: []
        }
    }

    /// The pair a category starts on before you pick anything.
    public var defaultPair: (from: String, to: String) {
        switch self {
        case .length: ("km", "mi")
        case .mass: ("kg", "lb")
        case .temperature: ("c", "f")
        case .volume: ("l", "gal")
        case .speed: ("kmh", "mph")
        case .area: ("m2", "ft2")
        case .data: ("GB", "MB")
        case .time: ("h", "min")
        case .currency: ("BRL", "USD")
        }
    }
}
