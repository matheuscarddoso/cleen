import Foundation

public struct DiskStats: Sendable, Equatable {
    public let total: Int64
    /// What macOS will make available when asked: free space plus purgeable data
    /// (iCloud copies, local snapshots, caches the system can drop). This is the number
    /// Finder shows.
    public let available: Int64
    /// Strictly free blocks right now.
    public let free: Int64

    public var purgeable: Int64 { max(0, available - free) }
    public var used: Int64 { max(0, total - available) }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    public static func read(volume: URL = URL(filePath: "/")) -> DiskStats? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? volume.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity
        else { return nil }
        let free = Int64(values.volumeAvailableCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage ?? free
        return DiskStats(total: Int64(total), available: max(available, free), free: free)
    }
}
