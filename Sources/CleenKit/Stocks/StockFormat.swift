import Foundation

/// How Ações writes its numbers, in the Mac's locale.
public enum StockFormat {
    /// `R$ 58,82`, `US$ 178,40` in Portuguese (`$178.40` in English). An index is in
    /// points, not money: `205.592,73`.
    public static func price(_ quote: StockQuote, locale: Locale = .cleen) -> String {
        price(quote.price, currency: quote.isIndex ? nil : quote.currency, fractionDigits: quote.fractionDigits, locale: locale)
    }

    public static func price(_ value: Double, currency: String?, fractionDigits: Int = 2, locale: Locale = .cleen) -> String {
        let digits = min(max(fractionDigits, 0), 6)
        guard let currency, currency.count == 3 else {
            return value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
        }
        return value.formatted(.currency(code: currency).precision(.fractionLength(digits)).locale(locale))
    }

    /// `+1,53%`, `-0,48%`, `0,00%`: always signed, two decimals, for the change pill.
    public static func change(_ fraction: Double, locale: Locale = .cleen) -> String {
        // Rounded first so a tiny loss doesn't print as "-0,00%".
        let rounded = (fraction * 10_000).rounded() / 10_000
        return (rounded == 0 ? 0 : rounded).formatted(
            .percent.precision(.fractionLength(2)).sign(strategy: .always(includingZero: false)).locale(locale)
        )
    }

    /// `+0,99` in the quote's units, for VoiceOver and the tooltip.
    public static func absoluteChange(_ quote: StockQuote, locale: Locale = .cleen) -> String? {
        guard let change = quote.change else { return nil }
        let digits = min(max(quote.fractionDigits, 0), 6)
        let step = pow(10, Double(digits))
        let rounded = (change * step).rounded() / step
        return (rounded == 0 ? 0 : rounded).formatted(
            .number.precision(.fractionLength(digits)).sign(strategy: .always(includingZero: false)).locale(locale)
        )
    }
}

/// The intraday line, laid out in a unit square: x from the session's open to its close
/// (so at noon the line stops halfway), y from the day's low to its high, with the
/// previous close inside the range so the baseline is always on the chart.
public enum StockChart {
    public struct Point: Equatable, Sendable {
        public var x: Double
        /// 0 at the bottom.
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Layout: Equatable, Sendable {
        public var points: [Point]
        /// Where the previous close sits, 0 at the bottom.
        public var baseline: Double?
    }

    public static func layout(_ quote: StockQuote) -> Layout {
        let points = quote.points
        guard !points.isEmpty else { return Layout(points: [], baseline: nil) }

        var low = points.map(\.close).min()!
        var high = points.map(\.close).max()!
        if let previous = quote.previousClose {
            low = min(low, previous)
            high = max(high, previous)
        }
        let span = high - low
        func y(_ value: Double) -> Double {
            span > 0 ? (value - low) / span : 0.5
        }

        let xs = xPositions(points.map(\.time), start: quote.sessionStart, end: quote.sessionEnd)
        let laidOut = zip(xs, points).map { Point(x: $0, y: y($1.close)) }
        return Layout(points: laidOut, baseline: quote.previousClose.map(y))
    }

    /// Along the session when its times fit the points; evenly spaced otherwise (no
    /// session, or a cached chart from another day).
    static func xPositions(_ times: [Date], start: Date?, end: Date?) -> [Double] {
        if let start, let end, end > start, let first = times.first, let last = times.last,
           first >= start.addingTimeInterval(-3600), last <= end.addingTimeInterval(3600) {
            let length = end.timeIntervalSince(start)
            return times.map { min(max($0.timeIntervalSince(start) / length, 0), 1) }
        }
        guard times.count > 1 else { return times.map { _ in 1 } }
        return times.indices.map { Double($0) / Double(times.count - 1) }
    }
}

/// When Ações asks again. Prices move by the minute, so every minute while it's on
/// screen; after Yahoo says "too many requests", it waits a while.
public enum StockRefresh {
    public static let interval: TimeInterval = 60
    public static let backoff: TimeInterval = 5 * 60

    public static func nextRefresh(fetchedAt: Date?, lastAttempt: Date?, rateLimited: Bool) -> Date {
        let due = fetchedAt.map { $0 + interval } ?? .distantPast
        guard let lastAttempt else { return due }
        return max(due, lastAttempt + (rateLimited ? backoff : interval))
    }

    /// Old enough that the "Atualizado às" note should show: two refreshes missed.
    public static func isStale(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > 3 * interval
    }
}
