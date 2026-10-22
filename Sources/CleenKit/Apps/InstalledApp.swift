import Foundation

public struct InstalledApp: Sendable, Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    /// The name shown in Finder.
    public let name: String
    /// Every name the app might use for its folders in `~/Library`.
    public let matchNames: [String]
    public let bundleID: String
    public let version: String?
    public let size: Int64
    public let lastUsed: Date?
    public let isAppStore: Bool
    /// Apps that ship with macOS (or are kept by it, like Safari) are listed for size
    /// but can't be removed.
    public let isSystem: Bool
    /// Installed by a package as root; removing needs an administrator password.
    public let needsAdministrator: Bool
}
