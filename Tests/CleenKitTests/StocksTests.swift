import Foundation
import Testing
@testable import CleenKit

struct StocksTests {
    /// A real chart response for PETR4.SA on 2026-10-23, trimmed to five closes (one of
    /// them a gap, as Yahoo sends for a minute with no trades).
    private let chartJSON = """
    {"chart":{"result":[{"meta":{"currency":"BRL","symbol":"PETR4.SA","exchangeName":"SAO","instrumentType":"EQUITY","regularMarketTime":1792779990,"gmtoffset":-10800,"exchangeTimezoneName":"America/Sao_Paulo","regularMarketPrice":58.82,"longName":"Petróleo Brasileiro S.A. - Petrobras","shortName":"PETROBRAS   PN      N2","chartPreviousClose":57.83,"previousClose":57.83,"priceHint":2,"currentTradingPeriod":{"pre":{"timezone":"BRT","start":1792759500,"end":1792760400,"gmtoffset":-10800},"regular":{"timezone":"BRT","start":1792760400,"end":1792785600,"gmtoffset":-10800},"post":{"timezone":"BRT","start":1792785600,"end":1792789200,"gmtoffset":-10800}},"tradingPeriods":[[{"timezone":"BRT","start":1792760400,"end":1792785600,"gmtoffset":-10800}]],"dataGranularity":"5m","range":"1d"},"timestamp":[1792760400,1792760700,1792761000,1792761300,1792779990],"indicators":{"quote":[{"close":[58.34,58.51,null,58.5,58.82],"open":[58.34,58.51,null,58.5,58.82]}]}}],"error":null}}
    """

    /// The answer for a symbol Yahoo doesn't know (HTTP 404).
    private let notFoundJSON = """
    {"chart":{"result":null,"error":{"code":"Not Found","description":"No data found, symbol may be delisted"}}}
    """

    /// A real search for "petro", trimmed to three hits.
    private let searchJSON = """
    {"explains":[],"count":3,"quotes":[{"exchange":"NYQ","shortname":"Occidental Petroleum Corporatio","quoteType":"EQUITY","symbol":"OXY","typeDisp":"Equity","longname":"Occidental Petroleum Corporation","exchDisp":"NYSE","isYahooFinance":true},{"exchange":"NYQ","shortname":"Petroleo Brasileiro S.A. Petrob","quoteType":"EQUITY","symbol":"PBR","typeDisp":"Equity","longname":"Petróleo Brasileiro S.A. - Petrobras","exchDisp":"NYSE","isYahooFinance":true},{"exchange":"SAO","shortname":"PETROBRAS   PN      N2","quoteType":"EQUITY","symbol":"PETR4.SA","typeDisp":"Equity","exchDisp":"São Paulo","isYahooFinance":true}],"news":[]}
    """

    private let fetched = Date(timeIntervalSince1970: 1_792_780_000)
    private let portuguese = Locale(identifier: "pt_BR")
    private let english = Locale(identifier: "en_US")

    private func quote() throws -> StockQuote {
        try #require(YahooFinance.parseChart(Data(chartJSON.utf8), fetchedAt: fetched))
    }

    /// Formatters put a no-break space between the currency and the number.
    private func plain(_ text: String) -> String {
        text.replacing("\u{00A0}", with: " ").replacing("\u{202F}", with: " ")
    }

    // MARK: Parsing

    @Test func parsesChart() throws {
        let quote = try quote()
        #expect(quote.symbol == "PETR4.SA")
        #expect(quote.displaySymbol == "PETR4")
        #expect(quote.name == "Petróleo Brasileiro S.A. - Petrobras")
        #expect(quote.currency == "BRL")
        #expect(quote.price == 58.82)
        #expect(quote.previousClose == 57.83)
        #expect(quote.fractionDigits == 2)
        #expect(quote.marketTime == Date(timeIntervalSince1970: 1_792_779_990))
        #expect(quote.regularStart == Date(timeIntervalSince1970: 1_792_760_400))
        #expect(quote.regularEnd == Date(timeIntervalSince1970: 1_792_785_600))
        #expect(quote.sessionStart == quote.regularStart)
        #expect(quote.fetchedAt == fetched)
        // The gap is dropped, not drawn as zero.
        #expect(quote.points.map(\.close) == [58.34, 58.51, 58.5, 58.82])
        #expect(quote.direction == .up)
        #expect(abs((quote.changeFraction ?? 0) - 0.017119) < 0.00001)
    }

    @Test func shortNameIsCleanedWhenThereIsNoLongName() throws {
        let json = chartJSON.replacing(#""longName":"Petróleo Brasileiro S.A. - Petrobras","#, with: "")
        let quote = try #require(YahooFinance.parseChart(Data(json.utf8), fetchedAt: fetched))
        #expect(quote.name == "PETROBRAS PN N2")
    }

    @Test func toleratesTradingPeriodsWithPrePost() throws {
        let json = chartJSON.replacing(
            #""tradingPeriods":[[{"timezone":"BRT","start":1792760400,"end":1792785600,"gmtoffset":-10800}]]"#,
            with: #""tradingPeriods":{"pre":[[{"start":1}]],"regular":[[{"start":1792760400,"end":1792785600}]],"post":[[]]}"#
        )
        let quote = try #require(YahooFinance.parseChart(Data(json.utf8), fetchedAt: fetched))
        #expect(quote.sessionEnd == Date(timeIntervalSince1970: 1_792_785_600))
    }

    @Test func rejectsAnswersWithoutAQuote() {
        #expect(YahooFinance.parseChart(Data(notFoundJSON.utf8), fetchedAt: fetched) == nil)
        #expect(YahooFinance.parseChart(Data("Too Many Requests".utf8), fetchedAt: fetched) == nil)
        #expect(YahooFinance.parseChart(Data(#"{"chart":{"result":[{"meta":{"symbol":"X"}}]}}"#.utf8), fetchedAt: fetched) == nil)
    }

    @Test func survivesACachedRoundTrip() throws {
        let quote = try quote()
        let data = try JSONEncoder().encode(quote)
        #expect(try JSONDecoder().decode(StockQuote.self, from: data) == quote)
    }

    @Test func parsesSearch() throws {
        let results = try #require(YahooFinance.parseSearch(Data(searchJSON.utf8)))
        #expect(results.map(\.symbol) == ["OXY", "PBR", "PETR4.SA"])
        #expect(results[2].name == "PETROBRAS PN N2")
        #expect(results[2].displaySymbol == "PETR4")
        #expect(results[2].exchange == "São Paulo")
        #expect(YahooFinance.parseSearch(Data(#"{"count":0,"quotes":[]}"#.utf8)) == [])
        #expect(YahooFinance.parseSearch(Data("<html>".utf8)) == nil)
    }

    @Test func exactTickerComesFirst() throws {
        let results = try #require(YahooFinance.parseSearch(Data(searchJSON.utf8)))
        #expect(StockSymbol.ranked(results, for: " petr4 ").map(\.symbol) == ["PETR4.SA", "OXY", "PBR"])
        #expect(StockSymbol.ranked(results, for: "petro").map(\.symbol) == ["OXY", "PBR", "PETR4.SA"])
    }

    // MARK: URLs

    @Test func urls() {
        #expect(YahooFinance.chartURL(symbol: "^BVSP").absoluteString == "https://query1.finance.yahoo.com/v8/finance/chart/%5EBVSP?range=1d&interval=5m")
        #expect(YahooFinance.chartURL(symbol: "BRL=X").absoluteString.contains("/chart/BRL=X?"))
        #expect(YahooFinance.searchURL(query: "vale 3").absoluteString == "https://query1.finance.yahoo.com/v1/finance/search?q=vale%203&quotesCount=6&newsCount=0")
    }

    // MARK: Symbols

    @Test(arguments: [
        (" aapl ", "AAPL"), ("^bvsp", "^BVSP"), ("btc-usd", "BTC-USD"), ("brl=x", "BRL=X"), ("petr4.sa", "PETR4.SA"),
    ])
    func normalizes(text: String, symbol: String) {
        #expect(StockSymbol.normalize(text) == symbol)
    }

    @Test(arguments: ["", "   ", "../etc", "A/B", "AAPL?x=1", "..", "^", "ÇÃO", String(repeating: "A", count: 21)])
    func rejects(text: String) {
        #expect(StockSymbol.normalize(text) == nil)
    }

    @Test func b3TickersGetTheirSuffix() {
        #expect(StockSymbol.lookup("petr4") == "PETR4.SA")
        #expect(StockSymbol.lookup("TAEE11") == "TAEE11.SA")
        #expect(StockSymbol.lookup("PETR4.SA") == "PETR4.SA")
        #expect(StockSymbol.lookup("AAPL") == "AAPL")
        #expect(StockSymbol.lookup("^BVSP") == "^BVSP")
    }

    @Test func display() {
        #expect(StockSymbol.display("^BVSP") == "BVSP")
        #expect(StockSymbol.display("VALE3.SA") == "VALE3")
        #expect(StockSymbol.display("NVDA") == "NVDA")
    }

    @Test func editsTheWatchlist() {
        let list = StockSymbol.defaultWatchlist
        #expect(list == ["^BVSP", "AAPL", "NVDA", "PETR4.SA"])
        #expect(StockSymbol.adding("VALE3.SA", to: list) == list + ["VALE3.SA"])
        #expect(StockSymbol.adding("AAPL", to: list) == list)
        let full = (0..<StockSymbol.maximumCount).map { "T\($0)" }
        #expect(StockSymbol.adding("MORE", to: full) == full)
        #expect(StockSymbol.moving("PETR4.SA", to: "^BVSP", in: list) == ["PETR4.SA", "^BVSP", "AAPL", "NVDA"])
        #expect(StockSymbol.moving("^BVSP", to: "NVDA", in: list) == ["AAPL", "NVDA", "^BVSP", "PETR4.SA"])
        #expect(StockSymbol.moving("GONE", to: "NVDA", in: list) == list)
    }

    // MARK: Formatting

    @Test func prices() throws {
        let quote = try quote()
        #expect(plain(StockFormat.price(quote, locale: portuguese)) == "R$ 58,82")
        #expect(plain(StockFormat.price(178.4, currency: "USD", locale: portuguese)) == "US$ 178,40")
        #expect(plain(StockFormat.price(178.4, currency: "USD", locale: english)) == "$178.40")
        #expect(StockFormat.price(205_592.73, currency: nil, locale: portuguese) == "205.592,73")
        var index = quote
        index.instrumentType = "INDEX"
        index.price = 205_592.73
        #expect(StockFormat.price(index, locale: portuguese) == "205.592,73")
    }

    @Test func changes() throws {
        #expect(StockFormat.change(0.0153, locale: portuguese) == "+1,53%")
        #expect(StockFormat.change(-0.0048, locale: portuguese) == "-0,48%")
        #expect(StockFormat.change(-0.00001, locale: portuguese) == "0,00%")
        #expect(StockFormat.change(0.0153, locale: english) == "+1.53%")
        #expect(try StockFormat.absoluteChange(quote(), locale: portuguese) == "+0,99")
    }

    @Test func tinyChangesAreFlat() throws {
        var quote = try quote()
        quote.price = 57.8301
        #expect(quote.direction == .flat)
        quote.price = 57.5
        #expect(quote.direction == .down)
        quote.previousClose = nil
        #expect(quote.direction == .flat)
        #expect(quote.changeFraction == nil)
    }

    // MARK: Market and refresh

    @Test func marketHours() throws {
        let quote = try quote()
        #expect(quote.isMarketOpen(at: Date(timeIntervalSince1970: 1_792_770_000)))
        #expect(!quote.isMarketOpen(at: Date(timeIntervalSince1970: 1_792_785_600)))
        #expect(!quote.isMarketOpen(at: Date(timeIntervalSince1970: 1_792_750_000)))
        var noHours = quote
        noHours.regularStart = nil
        #expect(noHours.isMarketOpen(at: quote.marketTime + 60))
        #expect(!noHours.isMarketOpen(at: quote.marketTime + 3600))
    }

    @Test func refreshTiming() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(StockRefresh.nextRefresh(fetchedAt: nil, lastAttempt: nil, rateLimited: false) == .distantPast)
        #expect(StockRefresh.nextRefresh(fetchedAt: now, lastAttempt: now, rateLimited: false) == now + 60)
        #expect(StockRefresh.nextRefresh(fetchedAt: now - 600, lastAttempt: now, rateLimited: false) == now + 60)
        #expect(StockRefresh.nextRefresh(fetchedAt: now, lastAttempt: now, rateLimited: true) == now + 300)
        #expect(!StockRefresh.isStale(fetchedAt: now - 120, now: now))
        #expect(StockRefresh.isStale(fetchedAt: now - 600, now: now))
    }

    // MARK: Chart

    @Test func chartFollowsTheSession() throws {
        let layout = StockChart.layout(try quote())
        #expect(layout.points.count == 4)
        // The session runs 25 200 s; the last close is 19 590 s in.
        #expect(layout.points.first?.x == 0)
        #expect(abs((layout.points.last?.x ?? 0) - 19_590.0 / 25_200.0) < 0.0001)
        // The previous close (57,83) is the day's low here, so the baseline sits at the bottom.
        #expect(layout.baseline == 0)
        #expect(layout.points.last?.y == 1)
        #expect(layout.points.allSatisfy { (0...1).contains($0.y) })
    }

    @Test func chartWithoutSessionIsEvenlySpaced() throws {
        var quote = try quote()
        quote.sessionStart = nil
        #expect(StockChart.layout(quote).points.map(\.x) == [0, 1.0 / 3, 2.0 / 3, 1])
        // A cached chart from another day doesn't squash against one edge.
        quote.sessionStart = Date(timeIntervalSince1970: 1_792_846_800)
        quote.sessionEnd = Date(timeIntervalSince1970: 1_792_872_000)
        #expect(StockChart.layout(quote).points.map(\.x) == [0, 1.0 / 3, 2.0 / 3, 1])
    }

    @Test func flatChartSitsInTheMiddle() throws {
        var quote = try quote()
        quote.points = quote.points.map { StockQuote.Point(time: $0.time, close: 10) }
        quote.previousClose = 10
        let layout = StockChart.layout(quote)
        #expect(layout.points.allSatisfy { $0.y == 0.5 })
        #expect(layout.baseline == 0.5)
        quote.points = []
        #expect(StockChart.layout(quote).points.isEmpty)
    }
}
