import Foundation

/// When a tool's last scan is too old to show as current.
public enum ScanFreshness {
    /// How long a scan's numbers stand before seeing them again takes them again.
    public static let maxAge: TimeInterval = 10 * 60

    /// Whether a scan taken at `lastScan` (nil: never taken) is due again at `now`.
    public static func isDue(lastScan: Date?, now: Date = .now, maxAge: TimeInterval = maxAge) -> Bool {
        guard let lastScan else { return true }
        let age = now.timeIntervalSince(lastScan)
        // A clock set back leaves the scan "in the future": take it again rather than
        // trust it until the clock catches up.
        return age > maxAge || age < 0
    }
}
