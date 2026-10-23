import Foundation

/// Yahoo Finance's public chart and search endpoints: no key, no account. These two are
/// the only network calls the Ações tab makes.
public enum YahooFinance {
    public enum Failure: Error, Equatable {
        /// No connection, timeout, DNS: worth trying again on the next tick.
        case offline
        /// Yahoo has no such symbol.
        case notFound
        /// Too many requests: back off instead of asking again in a minute.
        case rateLimited
        /// The server answered with something that isn't a quote.
        case badResponse
    }

    /// Yahoo's edge turns away requests that don't look like a browser.
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    // MARK: URLs

    /// Today in five-minute closes. `symbol` must come from `StockSymbol.normalize`;
    /// the caret of an index is percent-encoded.
    public static func chartURL(symbol: String) -> URL {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-=")
        let path = symbol.addingPercentEncoding(withAllowedCharacters: allowed) ?? symbol
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "interval", value: "5m"),
        ]
        return components.url!
    }

    public static func searchURL(query: String) -> URL {
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v1/finance/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "quotesCount", value: "6"),
            URLQueryItem(name: "newsCount", value: "0"),
        ]
        return components.url!
    }

    // MARK: Fetching

    @concurrent
    public static func quote(_ symbol: String, now: Date = .now) async -> Result<StockQuote, Failure> {
        switch await load(chartURL(symbol: symbol), timeout: 15) {
        case .success(let data):
            guard let quote = parseChart(data, fetchedAt: now) else { return .failure(.badResponse) }
            return .success(quote)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    /// Up to six tickers matching `text`, the exact ticker first. Nothing is asked for a
    /// blank query.
    @concurrent
    public static func search(_ text: String) async -> Result<[StockSearchResult], Failure> {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .success([]) }
        switch await load(searchURL(query: query), timeout: 10) {
        case .success(let data):
            guard let results = parseSearch(data) else { return .failure(.badResponse) }
            return .success(StockSymbol.ranked(results, for: query))
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private static func load(_ url: URL, timeout: TimeInterval) async -> Result<Data, Failure> {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode {
            case 200: return .success(data)
            case 404: return .failure(.notFound)
            case 429: return .failure(.rateLimited)
            default: return .failure(.badResponse)
            }
        } catch {
            return .failure(.offline)
        }
    }

    // MARK: Parsing

    /// Reads a chart response. `nil` without a price; gaps in the closes (minutes with
    /// no trades) are dropped rather than drawn as zero.
    public static func parseChart(_ data: Data, fetchedAt: Date) -> StockQuote? {
        guard let raw = try? JSONDecoder().decode(RawChart.self, from: data),
              let result = raw.chart.result?.first,
              let price = result.meta.regularMarketPrice
        else { return nil }
        let meta = result.meta
        let symbol = meta.symbol ?? ""
        guard !symbol.isEmpty else { return nil }

        let closes = result.indicators?.quote?.first?.close ?? []
        var points: [StockQuote.Point] = []
        for (index, time) in (result.timestamp ?? []).enumerated() {
            guard let close = closes[safe: index] ?? nil, close.isFinite else { continue }
            points.append(StockQuote.Point(time: Date(timeIntervalSince1970: time), close: close))
        }

        let session = meta.tradingPeriods?.session
        let name = [meta.longName, meta.shortName].lazy.compactMap { $0.map(cleanName) }.first { !$0.isEmpty }
        return StockQuote(
            symbol: symbol,
            name: name ?? StockSymbol.display(symbol),
            currency: meta.currency,
            instrumentType: meta.instrumentType,
            price: price,
            previousClose: meta.chartPreviousClose ?? meta.previousClose,
            fractionDigits: min(max(meta.priceHint ?? 2, 2), 6),
            marketTime: meta.regularMarketTime.map { Date(timeIntervalSince1970: $0) } ?? fetchedAt,
            regularStart: meta.currentTradingPeriod?.regular?.start.map { Date(timeIntervalSince1970: $0) },
            regularEnd: meta.currentTradingPeriod?.regular?.end.map { Date(timeIntervalSince1970: $0) },
            sessionStart: session?.start.map { Date(timeIntervalSince1970: $0) },
            sessionEnd: session?.end.map { Date(timeIntervalSince1970: $0) },
            points: points,
            fetchedAt: fetchedAt
        )
    }

    /// Reads a search response, keeping hits that have a symbol, once each.
    public static func parseSearch(_ data: Data) -> [StockSearchResult]? {
        guard let raw = try? JSONDecoder().decode(RawSearch.self, from: data) else { return nil }
        var seen = Set<String>()
        var results: [StockSearchResult] = []
        for quote in raw.quotes ?? [] {
            guard quote.isYahooFinance != false,
                  let symbol = quote.symbol.flatMap(StockSymbol.normalize),
                  seen.insert(symbol).inserted
            else { continue }
            let name = [quote.longname, quote.shortname].lazy.compactMap { $0.map(cleanName) }.first { !$0.isEmpty }
            results.append(StockSearchResult(symbol: symbol, name: name ?? StockSymbol.display(symbol), exchange: quote.exchDisp, kind: quote.typeDisp))
        }
        return results
    }

    /// B3 short names come padded to fixed columns ("PETROBRAS   PN      N2").
    static func cleanName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // Field names mirror the API's keys.
    private struct RawChart: Decodable {
        struct Chart: Decodable {
            var result: [Result]?
        }

        struct Result: Decodable {
            var meta: Meta
            var timestamp: [Double]?
            var indicators: Indicators?
        }

        struct Meta: Decodable {
            var symbol: String?
            var currency: String?
            var instrumentType: String?
            var regularMarketPrice: Double?
            var chartPreviousClose: Double?
            var previousClose: Double?
            var regularMarketTime: Double?
            var priceHint: Int?
            var longName: String?
            var shortName: String?
            var currentTradingPeriod: TradingPeriods?
            var tradingPeriods: Sessions?
        }

        struct TradingPeriods: Decodable {
            var regular: Period?
        }

        struct Period: Decodable {
            var start: Double?
            var end: Double?
        }

        /// `[[Period]]` for regular hours only, an object of them when pre and post
        /// market are included. Either way the chart's session; anything else is
        /// ignored rather than failing the quote.
        struct Sessions: Decodable {
            var session: Period?

            private struct Split: Decodable {
                var regular: [[Period]]?
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let periods = try? container.decode([[Period]].self) {
                    session = periods.first?.first
                } else if let split = try? container.decode(Split.self) {
                    session = split.regular?.first?.first
                }
            }
        }

        struct Indicators: Decodable {
            struct Quote: Decodable {
                var close: [Double?]?
            }

            var quote: [Quote]?
        }

        var chart: Chart
    }

    private struct RawSearch: Decodable {
        struct Quote: Decodable {
            var symbol: String?
            var shortname: String?
            var longname: String?
            var exchDisp: String?
            var typeDisp: String?
            var isYahooFinance: Bool?
        }

        var quotes: [Quote]?
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
