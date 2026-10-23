import Foundation

/// One unit the converter offers: a stable id (what's remembered), the name the picker
/// shows and a short symbol for the "1 km = 0,6214 mi" line.
public struct ConverterUnit: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let symbol: String

    public init(_ id: String, _ name: String, _ symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }

    /// Foundation's unit for this id. Built on demand: `Dimension` is a class, so a
    /// static table of them couldn't be shared across threads.
    var dimension: Dimension? {
        switch id {
        // Length
        case "mm": UnitLength.millimeters
        case "cm": UnitLength.centimeters
        case "m": UnitLength.meters
        case "km": UnitLength.kilometers
        case "in": UnitLength.inches
        case "ft": UnitLength.feet
        case "yd": UnitLength.yards
        case "mi": UnitLength.miles
        case "nmi": UnitLength.nauticalMiles
        // Mass
        case "mg": UnitMass.milligrams
        case "g": UnitMass.grams
        case "kg": UnitMass.kilograms
        case "t": UnitMass.metricTons
        case "oz": UnitMass.ounces
        case "lb": UnitMass.pounds
        case "st": UnitMass.stones
        // Temperature
        case "c": UnitTemperature.celsius
        case "f": UnitTemperature.fahrenheit
        case "k": UnitTemperature.kelvin
        // Volume
        case "ml": UnitVolume.milliliters
        case "l": UnitVolume.liters
        case "m3": UnitVolume.cubicMeters
        case "tsp": UnitVolume.teaspoons
        case "tbsp": UnitVolume.tablespoons
        case "cup": UnitVolume.cups
        case "floz": UnitVolume.fluidOunces
        case "gal": UnitVolume.gallons
        case "galuk": UnitVolume.imperialGallons
        // Speed
        case "mps": UnitSpeed.metersPerSecond
        case "kmh": UnitSpeed.kilometersPerHour
        case "mph": UnitSpeed.milesPerHour
        case "kn": UnitSpeed.knots
        // Area
        case "cm2": UnitArea.squareCentimeters
        case "m2": UnitArea.squareMeters
        case "ha": UnitArea.hectares
        case "km2": UnitArea.squareKilometers
        case "ft2": UnitArea.squareFeet
        case "ac": UnitArea.acres
        case "mi2": UnitArea.squareMiles
        // Data
        case "bit": UnitInformationStorage.bits
        case "B": UnitInformationStorage.bytes
        case "KB": UnitInformationStorage.kilobytes
        case "MB": UnitInformationStorage.megabytes
        case "GB": UnitInformationStorage.gigabytes
        case "TB": UnitInformationStorage.terabytes
        case "PB": UnitInformationStorage.petabytes
        case "MiB": UnitInformationStorage.mebibytes
        case "GiB": UnitInformationStorage.gibibytes
        // Time: Foundation stops at hours, so days and longer are linear multiples of
        // the second (a year is the Gregorian average, 365,2425 days).
        case "ms": UnitDuration.milliseconds
        case "s": UnitDuration.seconds
        case "min": UnitDuration.minutes
        case "h": UnitDuration.hours
        case "d": UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))
        case "wk": UnitDuration(symbol: "sem", converter: UnitConverterLinear(coefficient: 604_800))
        case "yr": UnitDuration(symbol: "anos", converter: UnitConverterLinear(coefficient: 31_556_952))
        default: nil
        }
    }
}

public enum UnitConversion {
    /// Converts between two units of the same category. Currencies need `rates`;
    /// returns nil when a unit or a rate is missing.
    public static func convert(_ value: Double, from: ConverterUnit, to: ConverterUnit, rates: CurrencyRates? = nil) -> Double? {
        if from.id == to.id { return value }
        if let source = from.dimension, let target = to.dimension {
            // A length into a mass would silently produce nonsense through base units.
            guard type(of: source).baseUnit().symbol == type(of: target).baseUnit().symbol else { return nil }
            return target.converter.value(fromBaseUnitValue: source.converter.baseUnitValue(fromValue: value))
        }
        return rates?.convert(value, from: from.id, to: to.id)
    }
}
