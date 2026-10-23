import Foundation

/// When Tempo asks for a new forecast. Weather models update hourly at best, so every
/// half hour is fresh enough; after a failure it retries sooner, but not in a loop.
public enum WeatherRefresh {
    public static let interval: TimeInterval = 30 * 60
    public static let retryInterval: TimeInterval = 5 * 60

    /// - Parameters:
    ///   - fetchedAt: when the forecast on screen was fetched, `nil` when there's none
    ///     for the current place.
    ///   - lastAttempt: the last request, successful or not.
    ///   - failed: whether that request failed.
    public static func nextRefresh(fetchedAt: Date?, lastAttempt: Date?, failed: Bool) -> Date {
        let due = fetchedAt.map { $0 + interval } ?? .distantPast
        guard failed, let lastAttempt else { return due }
        return max(due, lastAttempt + retryInterval)
    }

    /// The forecast is old enough that the "Atualizado às" note should show even
    /// without a failure (the Mac slept, the panel stayed closed).
    public static func isStale(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > interval + 5 * 60
    }
}
