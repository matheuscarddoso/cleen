import Foundation

/// Leftovers of one app that is no longer installed.
public struct OrphanGroup: Sendable, Identifiable, Hashable {
    public var id: String { bundleID }
    public let bundleID: String
    public let items: [Leftover]

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    /// `com.spotify.client` → `Spotify`: the best name we can offer without the app.
    public var displayName: String {
        let parts = bundleID.split(separator: ".")
        let generic: Set<String> = ["client", "app", "mac", "macos", "desktop", "osx", "helper", "agent"]
        let meaningful = parts.dropFirst().last { !generic.contains($0.lowercased()) } ?? parts.last ?? Substring(bundleID)
        return meaningful.prefix(1).uppercased() + meaningful.dropFirst()
    }
}
