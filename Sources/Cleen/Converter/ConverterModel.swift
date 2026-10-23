import CleenKit
import Foundation
import Observation

/// The converter's state: which category, which pair of units per category, what was
/// typed, and the day's exchange rates. Everything but the rates' download is instant.
///
/// One instance for the app's lifetime, so switching tabs doesn't lose a download in
/// flight or what you typed.
@Observable
final class ConverterModel {
    static let shared = ConverterModel()

    enum RatesState: Equatable {
        case idle
        case loading
        case failed
    }

    var category: ConverterCategory {
        didSet {
            guard category != oldValue else { return }
            defaults.set(category.rawValue, forKey: Keys.category)
            if category == .currency { refreshRatesIfNeeded() }
        }
    }

    /// What's typed in the left box, per category.
    var input: String {
        get { inputs[category] ?? "1" }
        set {
            inputs[category] = newValue
            save(inputs, forKey: Keys.inputs)
        }
    }

    private(set) var rates: CurrencyRates?
    private(set) var ratesState = RatesState.idle

    @ObservationIgnored private let defaults = UserDefaults.standard
    private var pairs: [ConverterCategory: Pair]
    private var inputs: [ConverterCategory: String]
    @ObservationIgnored private var ratesTask: Task<Void, Never>?

    private struct Pair: Codable, Equatable {
        var from: String
        var to: String
    }

    private enum Keys {
        static let category = "converter.category"
        static let pairs = "converter.pairs"
        static let inputs = "converter.inputs"
        static let rates = "converter.rates"
    }

    private init() {
        category = defaults.string(forKey: Keys.category).flatMap(ConverterCategory.init(rawValue:)) ?? .length
        pairs = Self.load([ConverterCategory: Pair].self, forKey: Keys.pairs) ?? [:]
        inputs = Self.load([ConverterCategory: String].self, forKey: Keys.inputs) ?? [:]
        rates = Self.load(CurrencyRates.self, forKey: Keys.rates)
    }

    // MARK: Units

    /// The units the pickers offer. Currencies come from the rates; with none yet,
    /// just the default pair so the boxes still read sensibly.
    var units: [ConverterUnit] {
        guard category == .currency else { return category.units }
        if let rates { return rates.units }
        return ["BRL", "USD"].map { ConverterUnit($0, CurrencyRates.name(for: $0), $0) }
    }

    var from: ConverterUnit { unit(pair.from, fallback: 0) }
    var to: ConverterUnit { unit(pair.to, fallback: 1) }

    func setFrom(_ id: String) {
        var pair = pair
        // Picking the unit already on the other side swaps them, like the system's own
        // converters, instead of converting a unit into itself.
        if id == pair.to { pair.to = pair.from }
        pair.from = id
        pairs[category] = pair
        save(pairs, forKey: Keys.pairs)
    }

    func setTo(_ id: String) {
        var pair = pair
        if id == pair.from { pair.from = pair.to }
        pair.to = id
        pairs[category] = pair
        save(pairs, forKey: Keys.pairs)
    }

    /// Swaps the units and keeps the number: 5 BRL → USD becomes 5 USD → BRL.
    func swap() {
        let pair = pair
        pairs[category] = Pair(from: pair.to, to: pair.from)
        save(pairs, forKey: Keys.pairs)
    }

    private var pair: Pair {
        pairs[category] ?? Pair(from: category.defaultPair.from, to: category.defaultPair.to)
    }

    private func unit(_ id: String, fallback: Int) -> ConverterUnit {
        let units = units
        return units.first { $0.id == id } ?? units[min(fallback, units.count - 1)]
    }

    // MARK: Result

    var value: Double? { ConverterNumber.parse(input) }

    var result: Double? {
        value.flatMap { UnitConversion.convert($0, from: from, to: to, rates: rates) }
    }

    var resultText: String {
        result.map { ConverterNumber.format($0, isCurrency: category == .currency) } ?? "—"
    }

    /// "1 km = 0,6214 mi": the rate behind the numbers.
    var unitRateText: String? {
        guard let rate = UnitConversion.convert(1, from: from, to: to, rates: rates), from.id != to.id else { return nil }
        return "1 \(from.symbol) = \(ConverterNumber.format(rate)) \(to.symbol)"
    }

    // MARK: Rates

    /// Downloads the rates when there are none or they're over 12 hours old. Called when
    /// Moeda is on screen, so the converter never touches the network otherwise.
    func refreshRatesIfNeeded() {
        guard ratesTask == nil, rates?.isStale() ?? true else { return }
        ratesState = .loading
        ratesTask = Task {
            defer { ratesTask = nil }
            do {
                let fresh = try await CurrencyRates.fetch()
                rates = fresh
                ratesState = .idle
                save(fresh, forKey: Keys.rates)
            } catch {
                ratesState = .failed
            }
        }
    }

    // MARK: Storage

    private func save(_ value: some Encodable, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
