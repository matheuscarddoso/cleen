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
        case .length: "Comprimento"
        case .mass: "Massa"
        case .temperature: "Temperatura"
        case .volume: "Volume"
        case .speed: "Velocidade"
        case .area: "Área"
        case .data: "Dados"
        case .time: "Tempo"
        case .currency: "Moeda"
        }
    }

    /// The units on offer, in the order the picker lists them. Currencies come from the
    /// rates instead (see `CurrencyRates.units`).
    public var units: [ConverterUnit] {
        switch self {
        case .length: [
            .init("mm", "Milímetros", "mm"), .init("cm", "Centímetros", "cm"), .init("m", "Metros", "m"),
            .init("km", "Quilômetros", "km"), .init("in", "Polegadas", "pol"), .init("ft", "Pés", "pés"),
            .init("yd", "Jardas", "jd"), .init("mi", "Milhas", "mi"), .init("nmi", "Milhas náuticas", "mn"),
        ]
        case .mass: [
            .init("mg", "Miligramas", "mg"), .init("g", "Gramas", "g"), .init("kg", "Quilos", "kg"),
            .init("t", "Toneladas", "t"), .init("oz", "Onças", "oz"), .init("lb", "Libras", "lb"),
            .init("st", "Stones", "st"),
        ]
        case .temperature: [
            .init("c", "Celsius", "°C"), .init("f", "Fahrenheit", "°F"), .init("k", "Kelvin", "K"),
        ]
        case .volume: [
            .init("ml", "Mililitros", "ml"), .init("l", "Litros", "l"), .init("m3", "Metros cúbicos", "m³"),
            .init("tsp", "Colheres de chá", "c. chá"), .init("tbsp", "Colheres de sopa", "c. sopa"),
            .init("cup", "Xícaras", "xíc."), .init("floz", "Onças líquidas", "fl oz"),
            .init("gal", "Galões (EUA)", "gal"), .init("galuk", "Galões (RU)", "gal RU"),
        ]
        case .speed: [
            .init("mps", "Metros por segundo", "m/s"), .init("kmh", "Quilômetros por hora", "km/h"),
            .init("mph", "Milhas por hora", "mph"), .init("kn", "Nós", "nós"),
        ]
        case .area: [
            .init("cm2", "Centímetros quadrados", "cm²"), .init("m2", "Metros quadrados", "m²"),
            .init("ha", "Hectares", "ha"), .init("km2", "Quilômetros quadrados", "km²"),
            .init("ft2", "Pés quadrados", "pés²"), .init("ac", "Acres", "ac"), .init("mi2", "Milhas quadradas", "mi²"),
        ]
        case .data: [
            .init("bit", "Bits", "bit"), .init("B", "Bytes", "B"), .init("KB", "Kilobytes", "KB"),
            .init("MB", "Megabytes", "MB"), .init("GB", "Gigabytes", "GB"), .init("TB", "Terabytes", "TB"),
            .init("PB", "Petabytes", "PB"), .init("MiB", "Mebibytes", "MiB"), .init("GiB", "Gibibytes", "GiB"),
        ]
        case .time: [
            .init("ms", "Milissegundos", "ms"), .init("s", "Segundos", "s"), .init("min", "Minutos", "min"),
            .init("h", "Horas", "h"), .init("d", "Dias", "d"), .init("wk", "Semanas", "sem"), .init("yr", "Anos", "anos"),
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
