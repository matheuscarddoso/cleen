import Foundation

/// A conversion typed into the search: `5 km em mi`, `72 f em c`, `100 usd em brl`,
/// `R$ 50 para euro`, `1,5 gb em mb`. A currency on its own (`100 usd`) goes to the
/// Mac's currency, or to dollars when it already is that.
public struct UnitQuery: Equatable, Sendable {
    public let value: Double
    public let from: ConverterUnit
    public let to: ConverterUnit
    public let isCurrency: Bool

    /// nil unless the text reads as a conversion. Currencies are recognized by code or
    /// common name; whether there's a rate for them is the caller's business.
    public static func parse(_ text: String, localCurrency: String = Locale.cleen.currency?.identifier ?? "BRL") -> UnitQuery? {
        var words = tokenize(text)
        guard !words.isEmpty else { return nil }
        // "R$ 100", "$100", "€ 20": the currency before the number.
        var leadingUnit: Resolved?
        if let first = words.first, ConverterNumber.parse(first) == nil, let unit = resolve(first), unit.isCurrency, words.count > 1 {
            leadingUnit = unit
            words.removeFirst()
        }
        guard let number = words.first.flatMap(ConverterNumber.parse) else { return nil }
        words.removeFirst()

        let connectors: Set<String> = ["em", "para", "pra", "to", "in", "->", "→", "=", "as"]
        let source: Resolved
        if let leadingUnit {
            source = leadingUnit
        } else {
            guard let next = words.first, let unit = resolveLongest(&words) ?? resolve(next).map({ unit in words.removeFirst(); return unit }) else { return nil }
            source = unit
        }
        if let first = words.first, connectors.contains(first) { words.removeFirst() }

        let target: Resolved
        if words.isEmpty {
            guard source.isCurrency else { return nil }
            let fallback = source.unit.id == localCurrency ? (localCurrency == "USD" ? "EUR" : "USD") : localCurrency
            target = Resolved(unit: ConverterUnit(fallback, CurrencyRates.name(for: fallback), fallback), category: nil)
        } else {
            guard let unit = resolveLongest(&words) ?? resolve(words[0]).map({ unit in words.removeFirst(); return unit }), words.isEmpty else { return nil }
            target = unit
        }
        guard source.unit.id != target.unit.id, source.isCurrency == target.isCurrency, source.category == target.category else { return nil }
        return UnitQuery(value: number, from: source.unit, to: target.unit, isCurrency: source.isCurrency)
    }

    /// The answer, given the day's rates for currencies.
    public func result(rates: CurrencyRates?) -> Double? {
        UnitConversion.convert(value, from: from, to: to, rates: isCurrency ? rates : nil)
    }

    // MARK: Reading

    struct Resolved {
        let unit: ConverterUnit
        /// nil for a currency.
        let category: ConverterCategory?
        var isCurrency: Bool { category == nil }
    }

    /// Splits "5km", "72°f", "r$100" into number and unit; lowercases, keeps the
    /// separators a number needs.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        for raw in FuzzyMatch.fold(text).split(whereSeparator: \.isWhitespace) {
            var word = String(raw)
            // A currency sign glued to the number: "r$100", "$5", "€20".
            for sign in ["r$", "us$", "$", "€", "£", "¥"] where word.hasPrefix(sign) && word.count > sign.count {
                let rest = String(word.dropFirst(sign.count))
                if ConverterNumber.parse(rest) != nil {
                    tokens.append(sign)
                    word = rest
                }
                break
            }
            // A unit glued to the number: "5km", "72°f", "1,5gb".
            if let first = word.first, first.isNumber || first == "-" {
                let numberPart = word.prefix { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }
                let unitPart = word.dropFirst(numberPart.count)
                if !unitPart.isEmpty, ConverterNumber.parse(String(numberPart)) != nil {
                    tokens.append(String(numberPart))
                    tokens.append(String(unitPart))
                    continue
                }
            }
            tokens.append(word)
        }
        return tokens
    }

    /// Two-word names first ("libra esterlina", "pes quadrados"), then one word.
    static func resolveLongest(_ words: inout [String]) -> Resolved? {
        guard words.count >= 2, let unit = resolve(words[0] + " " + words[1]) else { return nil }
        words.removeFirst(2)
        return unit
    }

    static func resolve(_ word: String) -> Resolved? {
        let key = word.replacingOccurrences(of: "°", with: "")
        if let id = unitAliases[key] ?? unitAliases[word] {
            for category in ConverterCategory.allCases where category != .currency {
                if let unit = category.units.first(where: { $0.id == id }) { return Resolved(unit: unit, category: category) }
            }
        }
        if let code = currencyAliases[word] ?? (word.count == 3 && word.allSatisfy(\.isLetter) && Locale.Currency.isoCurrencies.contains { $0.identifier == word.uppercased() } ? word.uppercased() : nil) {
            return Resolved(unit: ConverterUnit(code, CurrencyRates.name(for: code), code), category: nil)
        }
        return nil
    }

    /// Folded words to unit ids. Only what people actually type; ambiguous short words
    /// ("b", "t", "m" for minutes) are left out on purpose.
    static let unitAliases: [String: String] = {
        var table: [String: String] = [:]
        func add(_ id: String, _ words: [String]) { for word in words { table[word] = id } }
        add("mm", ["mm", "milimetro", "milimetros", "millimeter", "millimeters"])
        add("cm", ["cm", "centimetro", "centimetros", "centimeter", "centimeters"])
        add("m", ["m", "metro", "metros", "meter", "meters", "metre", "metres"])
        add("km", ["km", "kms", "quilometro", "quilometros", "kilometro", "kilometros", "kilometer", "kilometers"])
        add("in", ["in", "pol", "polegada", "polegadas", "inch", "inches"])
        add("ft", ["ft", "pe", "pes", "foot", "feet"])
        add("yd", ["yd", "jarda", "jardas", "yard", "yards"])
        add("mi", ["mi", "milha", "milhas", "mile", "miles"])
        add("nmi", ["nmi", "milha nautica", "milhas nauticas"])
        add("mg", ["mg", "miligrama", "miligramas", "milligram", "milligrams"])
        add("g", ["g", "grama", "gramas", "gram", "grams"])
        add("kg", ["kg", "kgs", "quilo", "quilos", "kilo", "kilos", "quilograma", "quilogramas", "kilogram", "kilograms"])
        add("t", ["tonelada", "toneladas", "ton", "tons", "tonne", "tonnes"])
        add("oz", ["oz", "onca", "oncas", "ounce", "ounces"])
        add("lb", ["lb", "lbs", "libra", "libras", "pound", "pounds"])
        add("st", ["st", "stone", "stones"])
        add("c", ["c", "celsius", "centigrados"])
        add("f", ["f", "fahrenheit"])
        add("k", ["kelvin"])
        add("ml", ["ml", "mililitro", "mililitros", "milliliter", "milliliters"])
        add("l", ["l", "litro", "litros", "liter", "liters", "litre", "litres"])
        add("m3", ["m3", "m³", "metro cubico", "metros cubicos"])
        add("tsp", ["tsp", "colher de cha", "colheres de cha", "teaspoon", "teaspoons"])
        add("tbsp", ["tbsp", "colher de sopa", "colheres de sopa", "tablespoon", "tablespoons"])
        add("cup", ["xicara", "xicaras", "xic", "cup", "cups"])
        add("floz", ["floz", "fl oz"])
        add("gal", ["gal", "galao", "galoes", "gallon", "gallons"])
        add("mps", ["m/s", "mps"])
        add("kmh", ["km/h", "kmh", "kph"])
        add("mph", ["mph"])
        add("kn", ["knot", "knots", "kn"])
        add("cm2", ["cm2", "cm²"])
        add("m2", ["m2", "m²"])
        add("ha", ["ha", "hectare", "hectares"])
        add("km2", ["km2", "km²"])
        add("ft2", ["ft2", "ft²", "pes quadrados", "square feet", "sqft"])
        add("ac", ["ac", "acre", "acres"])
        add("mi2", ["mi2", "mi²"])
        add("bit", ["bit", "bits"])
        add("B", ["byte", "bytes"])
        add("KB", ["kb", "kilobyte", "kilobytes"])
        add("MB", ["mb", "megabyte", "megabytes"])
        add("GB", ["gb", "giga", "gigas", "gigabyte", "gigabytes"])
        add("TB", ["tb", "tera", "teras", "terabyte", "terabytes"])
        add("PB", ["pb", "petabyte", "petabytes"])
        add("MiB", ["mib", "mebibyte", "mebibytes"])
        add("GiB", ["gib", "gibibyte", "gibibytes"])
        add("ms", ["ms", "milissegundo", "milissegundos", "millisecond", "milliseconds"])
        add("s", ["s", "seg", "segundo", "segundos", "sec", "second", "seconds"])
        add("min", ["min", "mins", "minuto", "minutos", "minute", "minutes"])
        add("h", ["h", "hr", "hrs", "hora", "horas", "hour", "hours"])
        add("d", ["d", "dia", "dias", "day", "days"])
        add("wk", ["sem", "semana", "semanas", "week", "weeks", "wk"])
        add("yr", ["ano", "anos", "year", "years", "yr"])
        return table
    }()

    static let currencyAliases: [String: String] = [
        "r$": "BRL", "real": "BRL", "reais": "BRL",
        "$": "USD", "us$": "USD", "dolar": "USD", "dolares": "USD", "dollar": "USD", "dollars": "USD",
        "€": "EUR", "euro": "EUR", "euros": "EUR",
        "£": "GBP", "libra esterlina": "GBP", "libras esterlinas": "GBP",
        "¥": "JPY", "iene": "JPY", "ienes": "JPY", "yen": "JPY",
        "peso argentino": "ARS", "pesos argentinos": "ARS",
    ]
}
