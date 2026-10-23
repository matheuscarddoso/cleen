import Foundation
import Synchronization

/// Anthropic API list prices, per million tokens. Used to put a dollar figure on
/// Claude Code usage: what the same tokens would cost on the API, not what a
/// subscription actually charges.
public struct ModelPricing: Sendable, Equatable {
    public let input: Double
    public let output: Double
    public let cacheWrite: Double
    public let cacheRead: Double

    /// Picks the price for a model id like `claude-opus-5-5` or `claude-sonnet-4-6-20260101`.
    public static func forModel(_ model: String) -> ModelPricing? {
        // Asked once per entry, tens of thousands of times per refresh, for a handful of
        // distinct ids: remember each answer.
        if let known = memo.withLock({ $0[model] }) { return known }
        let found = resolve(model)
        memo.withLock { $0[model] = found }
        return found
    }

    private static let memo = Mutex<[String: ModelPricing?]>([:])

    private static func resolve(_ model: String) -> ModelPricing? {
        let id = model.lowercased()
        func has(_ part: String) -> Bool { id.contains(part) }
        // Most specific first.
        if has("fable") || has("mythos") { return ModelPricing(input: 10, output: 50, cacheWrite: 12.5, cacheRead: 0.25) }
        if has("opus-5-5") { return ModelPricing(input: 4, output: 20, cacheWrite: 5, cacheRead: 0.2) }
        if has("opus") { return ModelPricing(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5) }
        if has("sonnet-5") { return ModelPricing(input: 2, output: 10, cacheWrite: 2.5, cacheRead: 0.2) }
        if has("sonnet") { return ModelPricing(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3) }
        if has("haiku-5") { return ModelPricing(input: 0.1, output: 0.5, cacheWrite: 0.125, cacheRead: 0.01) }
        if has("haiku") { return ModelPricing(input: 1, output: 5, cacheWrite: 1.25, cacheRead: 0.1) }
        return nil
    }

    public func cost(of entry: UsageEntry) -> Double {
        (Double(entry.input) * input
            + Double(entry.output) * output
            + Double(entry.cacheWrite) * cacheWrite
            + Double(entry.cacheRead) * cacheRead) / 1_000_000
    }
}
