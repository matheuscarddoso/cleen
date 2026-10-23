import Foundation

/// One ticker as last fetched: the price now, where the day started, and today's line.
public struct StockQuote: Codable, Equatable, Sendable, Identifiable {
    /// One close of the intraday chart.
    public struct Point: Codable, Equatable, Sendable {
        public var time: Date
        public var close: Double

        public init(time: Date, close: Double) {
            self.time = time
            self.close = close
        }
    }

    /// Yahoo's symbol, exactly as requested ("PETR4.SA", "^BVSP").
    public var symbol: String
    public var name: String
    /// ISO 4217 code ("BRL", "USD"); `nil` for the rare quote that has none.
    public var currency: String?
    /// "EQUITY", "INDEX", "ETF", "CRYPTOCURRENCY"…
    public var instrumentType: String?
    public var price: Double
    /// The close the day's change is measured from.
    public var previousClose: Double?
    /// Decimals the exchange quotes in (Yahoo's `priceHint`).
    public var fractionDigits: Int
    /// When `price` was traded.
    public var marketTime: Date
    /// The regular session happening now or next, for open/closed.
    public var regularStart: Date?
    public var regularEnd: Date?
    /// The session `points` belong to: the chart's x axis.
    public var sessionStart: Date?
    public var sessionEnd: Date?
    public var points: [Point]
    public var fetchedAt: Date

    public init(
        symbol: String, name: String, currency: String?, instrumentType: String?, price: Double, previousClose: Double?,
        fractionDigits: Int = 2, marketTime: Date, regularStart: Date? = nil, regularEnd: Date? = nil,
        sessionStart: Date? = nil, sessionEnd: Date? = nil, points: [Point] = [], fetchedAt: Date
    ) {
        self.symbol = symbol
        self.name = name
        self.currency = currency
        self.instrumentType = instrumentType
        self.price = price
        self.previousClose = previousClose
        self.fractionDigits = fractionDigits
        self.marketTime = marketTime
        self.regularStart = regularStart
        self.regularEnd = regularEnd
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
        self.points = points
        self.fetchedAt = fetchedAt
    }

    public var id: String { symbol }

    public var isIndex: Bool { instrumentType == "INDEX" }

    /// The day's change in the quote's own units.
    public var change: Double? {
        previousClose.map { price - $0 }
    }

    /// The day's change as a fraction of the previous close (0.0153 = +1,53%).
    public var changeFraction: Double? {
        guard let previousClose, previousClose != 0 else { return nil }
        return (price - previousClose) / previousClose
    }

    public enum Direction: Sendable {
        case up
        case down
        case flat
    }

    /// Flat when the change would print as 0,00%, so the color never disagrees with the
    /// number next to it.
    public var direction: Direction {
        guard let fraction = changeFraction, abs(fraction) >= 0.00005 else { return .flat }
        return fraction > 0 ? .up : .down
    }

    /// Inside the regular session. Without session times (rare), a price traded in the
    /// last quarter hour counts as open.
    public func isMarketOpen(at now: Date) -> Bool {
        if let regularStart, let regularEnd, regularEnd > regularStart {
            return now >= regularStart && now < regularEnd
        }
        return now.timeIntervalSince(marketTime) < 15 * 60
    }

    /// "PETR4" for "PETR4.SA", "BVSP" for "^BVSP": the suffix and the index caret are
    /// Yahoo's plumbing, not how anyone says the ticker.
    public var displaySymbol: String { StockSymbol.display(symbol) }
}

/// A search hit: enough to show it and to add it.
public struct StockSearchResult: Equatable, Sendable, Identifiable {
    public var symbol: String
    public var name: String
    /// "São Paulo", "NASDAQ".
    public var exchange: String?
    /// "Equity", "Index", "ETF", as Yahoo writes it.
    public var kind: String?

    public init(symbol: String, name: String, exchange: String? = nil, kind: String? = nil) {
        self.symbol = symbol
        self.name = name
        self.exchange = exchange
        self.kind = kind
    }

    public var id: String { symbol }
    public var displaySymbol: String { StockSymbol.display(symbol) }
}
