import Foundation

/// The numbers the AI usage panel shows, computed from deduplicated entries.
public struct UsageSummary: Sendable, Equatable {
    public struct Day: Sendable, Equatable, Identifiable {
        public var id: Date { day }
        public let day: Date
        public let cost: Double
        public let tokens: Int
    }

    public struct ModelShare: Sendable, Equatable, Identifiable {
        public var id: String { name }
        public let name: String
        public let cost: Double
    }

    public let todayCost: Double
    public let todayTokens: Int
    public let monthCost: Double
    /// Last 14 days, oldest first, zero-filled.
    public let days: [Day]
    /// Last 30 days, most expensive first.
    public let models: [ModelShare]
    /// Claude's usage windows are five hours long, starting at the first message.
    public let blockStart: Date?
    public let blockCost: Double
    public let blockTokens: Int

    public init(entries: [UsageEntry], now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let monthStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let todays = entries.filter { $0.timestamp >= today }
        todayCost = todays.reduce(0) { $0 + $1.cost }
        todayTokens = todays.reduce(0) { $0 + $1.totalTokens }
        let month = entries.filter { $0.timestamp >= monthStart }
        monthCost = month.reduce(0) { $0 + $1.cost }

        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        days = (0..<14).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            let items = byDay[day] ?? []
            return Day(day: day, cost: items.reduce(0) { $0 + $1.cost }, tokens: items.reduce(0) { $0 + $1.totalTokens })
        }

        models = Dictionary(grouping: month) { Self.family(of: $0.model) }
            .map { ModelShare(name: $0.key, cost: $0.value.reduce(0) { $0 + $1.cost }) }
            .filter { $0.cost > 0 }
            .sorted { $0.cost > $1.cost }

        let block = Self.currentBlock(entries, now: now)
        blockStart = block.first?.timestamp
        blockCost = block.reduce(0) { $0 + $1.cost }
        blockTokens = block.reduce(0) { $0 + $1.totalTokens }
    }

    /// Entries in the active five-hour window: walk forward, opening a new window
    /// whenever a message lands after the previous window ended.
    static func currentBlock(_ entries: [UsageEntry], now: Date) -> [UsageEntry] {
        let length: TimeInterval = 5 * 3600
        var blockStart: Date?
        var block: [UsageEntry] = []
        for entry in entries {
            if let start = blockStart, entry.timestamp < start.addingTimeInterval(length) {
                block.append(entry)
            } else {
                // Windows start on the hour, the way Claude Code reports them.
                let start = Calendar.current.dateInterval(of: .hour, for: entry.timestamp)?.start ?? entry.timestamp
                blockStart = start
                block = [entry]
            }
        }
        guard let start = blockStart, now < start.addingTimeInterval(length) else { return [] }
        return block
    }

    /// `claude-opus-5-5` → `Opus 5.5`.
    public static func family(of model: String) -> String {
        let parts = model.lowercased().replacing("claude-", with: "").split(separator: "-")
        guard let name = parts.first else { return model }
        let version = parts.dropFirst().prefix { $0.allSatisfy(\.isNumber) && $0.count <= 2 }.joined(separator: ".")
        return name.prefix(1).uppercased() + name.dropFirst() + (version.isEmpty ? "" : " \(version)")
    }
}
