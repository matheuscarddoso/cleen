import Foundation

public struct ProcessUsage: Sendable, Identifiable, Equatable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    /// The `.app` the executable lives in, for its icon and to quit it gracefully.
    public let appURL: URL?
    /// Percent of one core, like Activity Monitor (can exceed 100).
    public let cpu: Double
    /// Physical footprint in bytes: the "Memória" column in Activity Monitor.
    public let memory: Int64
}
