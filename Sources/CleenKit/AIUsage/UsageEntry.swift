import Foundation

/// One assistant response's token usage, as Claude Code logged it.
public struct UsageEntry: Sendable, Hashable, Codable {
    public let timestamp: Date
    public let model: String
    public let input: Int
    public let output: Int
    public let cacheWrite: Int
    public let cacheRead: Int
    /// Message id + request id. Claude Code writes one line per content block, all
    /// repeating the same usage, so this is what deduplicates them.
    public let key: String

    public var totalTokens: Int { input + output + cacheWrite + cacheRead }

    public var cost: Double { ModelPricing.forModel(model)?.cost(of: self) ?? 0 }

    public init(timestamp: Date, model: String, input: Int, output: Int, cacheWrite: Int, cacheRead: Int, key: String) {
        self.timestamp = timestamp
        self.model = model
        self.input = input
        self.output = output
        self.cacheWrite = cacheWrite
        self.cacheRead = cacheRead
        self.key = key
    }
}
