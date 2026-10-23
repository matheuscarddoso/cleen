import Foundation

/// The day's reference exchange rates, as Frankfurter publishes them from the European
/// Central Bank: how many of each currency one unit of `base` buys.
public struct CurrencyRates: Codable, Sendable, Equatable {
    public let base: String
    /// The ECB's publication day, `yyyy-MM-dd` (no rates on weekends and holidays).
    public let date: String
    public let rates: [String: Double]
    /// When this copy was downloaded; decides when to ask again.
    public let fetchedAt: Date

    public init(base: String, date: String, rates: [String: Double], fetchedAt: Date) {
        self.base = base
        self.date = date
        var rates = rates
        rates[base] = 1
        self.rates = rates
        self.fetchedAt = fetchedAt
    }

    /// Asks again at most twice a day: the ECB publishes once, around 16:00 CET.
    public static let refreshInterval: TimeInterval = 12 * 3600

    public func isStale(at now: Date = .now) -> Bool {
        now.timeIntervalSince(fetchedAt) >= Self.refreshInterval || fetchedAt > now
    }

    /// Cross rate through the base: 1 BRL in USD is rate(USD) / rate(BRL).
    public func convert(_ value: Double, from: String, to: String) -> Double? {
        guard let source = rates[from], let target = rates[to], source > 0 else { return nil }
        return value / source * target
    }

    /// The publication day as a date, for "Cotação de 22 de out.".
    public var publishedOn: Date? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// Every currency on offer as picker units: the common ones first, the rest by name.
    public var units: [ConverterUnit] {
        let common = Self.commonCodes.filter { rates[$0] != nil }
        let rest = rates.keys.filter { !Self.commonCodes.contains($0) }
            .sorted { Self.name(for: $0).compare(Self.name(for: $1), locale: .cleen) == .orderedAscending }
        return (common + rest).map { ConverterUnit($0, Self.name(for: $0), $0) }
    }

    /// The currencies most people convert between, in the order the picker opens on.
    public static let commonCodes = ["BRL", "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "MXN"]

    /// "Real brasileiro", "Dólar americano": the system's own Portuguese names.
    public static func name(for code: String) -> String {
        guard let name = Locale.cleen.localizedString(forCurrencyCode: code) else { return code }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: Frankfurter

    public static let endpoint = URL(string: "https://api.frankfurter.app/latest?from=USD")!

    /// Reads Frankfurter's `{"amount":1,"base":"USD","date":"…","rates":{…}}`.
    public static func decode(_ data: Data, fetchedAt: Date = .now) throws -> CurrencyRates {
        struct Response: Decodable {
            let base: String
            let date: String
            let rates: [String: Double]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard !response.rates.isEmpty else { throw URLError(.cannotParseResponse) }
        return CurrencyRates(base: response.base, date: response.date, rates: response.rates, fetchedAt: fetchedAt)
    }

    /// Downloads today's rates. The one network call the converter makes; runs off the
    /// main actor.
    @concurrent
    public static func fetch() async throws -> CurrencyRates {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decode(data)
    }
}
