import Foundation

/// A download's speed and time left, from how many bytes have arrived when. The speed is
/// smoothed (an exponential average) so the estimate doesn't jump with every burst;
/// until a couple of seconds have gone by there's no estimate at all rather than a wild one.
public struct DownloadEstimate: Sendable, Equatable {
    public private(set) var completed: Int64 = 0
    public private(set) var total: Int64 = 0
    /// Bytes per second, smoothed; nil until it's been measured long enough.
    public private(set) var speed: Double?
    private var lastBytes: Int64?
    private var lastAt: Date?
    private var startedAt: Date?

    /// How much a new measurement moves the average.
    static let smoothing = 0.25
    /// The first estimate waits this long.
    static let warmUp: TimeInterval = 1.5

    public init() {}

    public var fraction: Double? {
        total > 0 ? min(1, Double(completed) / Double(total)) : nil
    }

    /// Seconds left, when both the size and a speed are known.
    public var remaining: TimeInterval? {
        guard total > 0, let speed, speed > 1 else { return nil }
        return max(0, Double(total - completed) / speed)
    }

    public mutating func update(completed: Int64, total: Int64, at now: Date = .now) {
        self.total = total
        if startedAt == nil { startedAt = now }
        defer {
            self.completed = completed
        }
        guard let lastBytes, let lastAt else {
            self.lastBytes = completed
            self.lastAt = now
            return
        }
        let elapsed = now.timeIntervalSince(lastAt)
        // Too close together to measure anything.
        guard elapsed >= 0.25 else { return }
        let rate = max(0, Double(completed - lastBytes) / elapsed)
        self.lastBytes = completed
        self.lastAt = now
        // The average builds from the first measurement; it's only shown after the warm-up.
        let base = measured ?? rate
        measured = base + Self.smoothing * (rate - base)
        if let startedAt, now.timeIntervalSince(startedAt) >= Self.warmUp { speed = measured }
    }

    private var measured: Double?

    /// The name a browser's unfinished file will have once it's done: Chrome's
    /// `.crdownload`, Safari's `.download`, Firefox's `.part`.
    public static func finalName(of name: String) -> String {
        for suffix in [".crdownload", ".download", ".partial", ".part"] where name.lowercased().hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }

    /// "20 s", "2 min", "1 h 5 min".
    public static func shortDuration(_ seconds: TimeInterval) -> (value: Int, unit: Unit, minutes: Int) {
        let total = Int(seconds.rounded(.up))
        if total < 60 { return (max(1, total), .seconds, 0) }
        if total < 3600 { return (Int((Double(total) / 60).rounded(.up)), .minutes, 0) }
        return (total / 3600, .hours, (total % 3600) / 60)
    }

    public enum Unit: Sendable { case seconds, minutes, hours }
}
