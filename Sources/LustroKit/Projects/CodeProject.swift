import Foundation

public struct CodeProject: Sendable, Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    /// Newest change among the project's own files (artifacts excluded, `.git/index`
    /// included, so a commit counts as activity).
    public let lastActivity: Date
    /// Largest first.
    public let artifacts: [ProjectArtifact]

    public var totalSize: Int64 { artifacts.reduce(0) { $0 + $1.size } }

    public func isStale(threshold: TimeInterval, now: Date = .now) -> Bool {
        now.timeIntervalSince(lastActivity) >= threshold
    }
}
