import Foundation

/// Ticker symbols: what counts as one, how it's shown, and the watchlist's edits.
public enum StockSymbol {
    /// Ibovespa, two US megacaps and Petrobras: a first list that shows both markets.
    public static let defaultWatchlist = ["^BVSP", "AAPL", "NVDA", "PETR4.SA"]

    /// More than this stops reading as a glance and costs a request a minute each.
    public static let maximumCount = 16

    /// Uppercased and trimmed, or `nil` when it can't be a Yahoo symbol. Only letters,
    /// digits and `. ^ = -` ("BRL=X", "BTC-USD", "^BVSP"), so a symbol is always safe to
    /// put in a URL path.
    public static func normalize(_ text: String) -> String? {
        let symbol = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (1...20).contains(symbol.count) else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.^=-")
        guard symbol.unicodeScalars.allSatisfy(allowed.contains),
              symbol.contains(where: { $0.isLetter || $0.isNumber }),
              !symbol.contains("..")
        else { return nil }
        return symbol
    }

    /// What typing a ticker and pressing + should look up. B3 tickers (four letters and
    /// a share class number: PETR4, TAEE11) live on Yahoo with a `.SA` suffix nobody
    /// types, and no other market uses that shape.
    public static func lookup(_ text: String) -> String? {
        guard let symbol = normalize(text) else { return nil }
        if symbol.wholeMatch(of: /[A-Z]{4}[0-9]{1,2}F?/) != nil { return symbol + ".SA" }
        return symbol
    }

    public static func display(_ symbol: String) -> String {
        var shown = symbol
        if shown.hasSuffix(".SA") { shown.removeLast(3) }
        if shown.hasPrefix("^") { shown.removeFirst() }
        return shown.isEmpty ? symbol : shown
    }

    /// The list with `symbol` at the end, unless it's already there or the list is full.
    public static func adding(_ symbol: String, to list: [String]) -> [String] {
        guard !list.contains(symbol), list.count < maximumCount else { return list }
        return list + [symbol]
    }

    /// The list with `symbol` moved into `target`'s place (a drop on another row).
    public static func moving(_ symbol: String, to target: String, in list: [String]) -> [String] {
        guard symbol != target, let from = list.firstIndex(of: symbol), let to = list.firstIndex(of: target) else { return list }
        var moved = list
        moved.remove(at: from)
        moved.insert(symbol, at: to)
        return moved
    }

    /// Search hits with the one whose ticker is exactly what was typed first: "petr4"
    /// should put PETR4.SA on top, however Yahoo ranks it.
    public static func ranked(_ results: [StockSearchResult], for query: String) -> [StockSearchResult] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let exact = results.filter { $0.displaySymbol == typed || $0.symbol == typed }
        return exact + results.filter { !exact.contains($0) }
    }
}
