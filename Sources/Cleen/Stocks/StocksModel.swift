import CleenKit
import Foundation
import Observation

/// The watchlist and its last quotes.
///
/// The list and the quotes are kept in UserDefaults, so the tab and the widget show the
/// last prices the moment they open, even offline. Prices are asked for once a minute,
/// and only while a view that shows them is on screen.
@Observable
final class StocksModel {
    /// Yahoo symbols in the person's order.
    private(set) var symbols: [String] = []
    /// The last quote of each symbol; kept when a refresh fails.
    private(set) var quotes: [String: StockQuote] = [:]
    /// Symbols Yahoo answered "not found" for (delisted, or a typo saved long ago).
    private(set) var unknown: Set<String> = []
    /// The saved list has been read back; until then the views show nothing rather than
    /// flashing an empty list.
    private(set) var isRestored = false
    private(set) var isLoading = false
    /// The last refresh got no prices at all (offline, Yahoo down).
    private(set) var lastRefreshFailed = false
    /// The symbol being looked up by `add`, for its spinner.
    private(set) var adding: String?

    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var rateLimited = false
    @ObservationIgnored private var restoring: Task<Void, Never>?
    /// The last write; each one waits for the one before, so a quick remove-then-move
    /// can't land out of order.
    @ObservationIgnored private var saving: Task<Void, Never>?

    private nonisolated static let symbolsKey = "stocks.symbols"
    private nonisolated static let quotesKey = "stocks.quotes"

    init() {
        restoring = Task { [weak self] in await self?.restore() }
    }

    /// Refreshes when due, then every minute, for as long as the calling view is on
    /// screen. Several views may watch at once; only one refresh is ever in flight.
    func watch() async {
        await restoring?.value
        while !Task.isCancelled {
            if !symbols.isEmpty, Date.now >= nextRefresh { await refresh() }
            try? await Task.sleep(for: .seconds(max(5, nextRefresh.timeIntervalSinceNow)))
        }
    }

    private var nextRefresh: Date {
        let wanted = symbols.filter { !unknown.contains($0) }
        // A symbol without a quote yet makes the whole list due.
        let fetched = wanted.map { quotes[$0]?.fetchedAt }
        let oldest = fetched.contains(where: { $0 == nil }) ? nil : fetched.compactMap(\.self).min()
        return StockRefresh.nextRefresh(fetchedAt: oldest, lastAttempt: lastAttempt, rateLimited: rateLimited)
    }

    /// Asks for every symbol at once; each answer stands on its own, so one bad ticker
    /// doesn't hold back the rest.
    func refresh() async {
        guard !isLoading, !symbols.isEmpty else { return }
        isLoading = true
        lastAttempt = .now
        let wanted = symbols
        let results = await withTaskGroup(of: (String, Result<StockQuote, YahooFinance.Failure>).self) { group in
            for symbol in wanted {
                group.addTask { (symbol, await YahooFinance.quote(symbol)) }
            }
            var all: [(String, Result<StockQuote, YahooFinance.Failure>)] = []
            for await result in group { all.append(result) }
            return all
        }
        isLoading = false

        var succeeded = 0
        var limited = false
        for (symbol, result) in results where symbols.contains(symbol) {
            switch result {
            case .success(let quote):
                quotes[symbol] = quote
                unknown.remove(symbol)
                succeeded += 1
            case .failure(.notFound):
                unknown.insert(symbol)
            case .failure(.rateLimited):
                limited = true
            case .failure:
                break
            }
        }
        let failed = results.count { symbol, result in
            if case .failure(let failure) = result { failure != .notFound } else { false }
        }
        rateLimited = limited
        lastRefreshFailed = succeeded == 0 && failed > 0
        if succeeded > 0 { saveQuotes() }
    }

    enum AddOutcome: Equatable {
        case added
        case alreadyListed
        case full
        case notFound
        case offline
        /// Another lookup is still running.
        case busy
    }

    /// Looks the symbol up and, when Yahoo knows it, puts it at the end of the list.
    /// A pick from the search is known to exist, so it's added even when the price can't
    /// be fetched right now; a typed ticker has to be found first.
    func add(_ symbol: String, verified: Bool) async -> AddOutcome {
        guard !symbols.contains(symbol) else { return .alreadyListed }
        guard symbols.count < StockSymbol.maximumCount else { return .full }
        guard adding == nil else { return .busy }
        adding = symbol
        let result = await YahooFinance.quote(symbol)
        adding = nil
        switch result {
        case .success(let quote):
            quotes[symbol] = quote
        case .failure(.notFound):
            return .notFound
        case .failure:
            if !verified { return .offline }
        }
        symbols = StockSymbol.adding(symbol, to: symbols)
        unknown.remove(symbol)
        saveSymbols()
        saveQuotes()
        return .added
    }

    func remove(_ symbol: String) {
        symbols.removeAll { $0 == symbol }
        quotes[symbol] = nil
        unknown.remove(symbol)
        saveSymbols()
        saveQuotes()
    }

    /// A row dropped on another takes its place.
    func move(_ symbol: String, to target: String) {
        let moved = StockSymbol.moving(symbol, to: target, in: symbols)
        guard moved != symbols else { return }
        symbols = moved
        saveSymbols()
    }

    // MARK: Status

    /// Quotes on the list, in its order.
    var listedQuotes: [StockQuote] {
        symbols.compactMap { quotes[$0] }
    }

    /// The newest price on screen, for "Atualizado às".
    var lastUpdate: Date? {
        listedQuotes.map(\.fetchedAt).max()
    }

    /// Every market on the list is outside its regular session.
    func allMarketsClosed(at now: Date) -> Bool {
        let listed = listedQuotes
        return !listed.isEmpty && listed.allSatisfy { !$0.isMarketOpen(at: now) }
    }

    /// The prices on screen are behind: the last refresh failed, or nothing has asked in
    /// a while (the Mac slept).
    func isBehind(at now: Date) -> Bool {
        guard let lastUpdate else { return false }
        return lastRefreshFailed || StockRefresh.isStale(fetchedAt: lastUpdate, now: now)
    }

    // MARK: Persistence

    private func restore() async {
        let (symbols, quotes) = await offMain {
            let defaults = UserDefaults.standard
            // Never saved means first run; an empty saved list is the person's choice.
            let symbols = defaults.object(forKey: Self.symbolsKey) == nil
                ? StockSymbol.defaultWatchlist
                : (defaults.stringArray(forKey: Self.symbolsKey) ?? []).compactMap(StockSymbol.normalize)
            let quotes = defaults.data(forKey: Self.quotesKey).flatMap { try? JSONDecoder().decode([String: StockQuote].self, from: $0) } ?? [:]
            return (symbols, quotes)
        }
        // Nothing can edit the list before this: the views wait for `isRestored`.
        self.symbols = symbols
        self.quotes = quotes.filter { symbols.contains($0.key) }
        isRestored = true
    }

    private func saveSymbols() {
        let symbols = symbols
        persist { UserDefaults.standard.set(symbols, forKey: Self.symbolsKey) }
    }

    private func saveQuotes() {
        let quotes = quotes.filter { symbols.contains($0.key) }
        persist {
            guard let data = try? JSONEncoder().encode(quotes) else { return }
            UserDefaults.standard.set(data, forKey: Self.quotesKey)
        }
    }

    private func persist(_ work: @escaping @Sendable () -> Void) {
        let previous = saving
        saving = Task {
            await previous?.value
            await offMain(work)
        }
    }
}
