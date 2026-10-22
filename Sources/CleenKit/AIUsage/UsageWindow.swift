import Foundation

/// One rate-limit window as a provider reports it: how full, and when it resets.
public struct UsageWindow: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    /// 0...1
    public let used: Double
    public let resetsAt: Date?
    public let length: TimeInterval

    public init(name: String, used: Double, resetsAt: Date?, length: TimeInterval) {
        self.name = name
        self.used = used
        self.resetsAt = resetsAt
        self.length = length
    }

    /// How far through the window we are, 0...1: where an even pace would put usage.
    public func elapsed(at now: Date = .now) -> Double? {
        guard let resetsAt, length > 0 else { return nil }
        return min(1, max(0, 1 - resetsAt.timeIntervalSince(now) / length))
    }

    /// Usage at reset if the current pace holds; > 1 means the limit hits first.
    public func projected(at now: Date = .now) -> Double? {
        guard let elapsed = elapsed(at: now), elapsed > 0.05 else { return nil }
        return used / elapsed
    }
}
