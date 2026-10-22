import Foundation

/// Where a junk category finds its candidates.
public struct JunkSource: Sendable, Hashable {
    public enum Shape: Sendable, Hashable {
        /// Every child of the folder is its own item. The folder itself stays.
        case contents
        /// The folder is a single item (e.g. "npm cache").
        case whole
        /// Files directly inside the folder whose extension is in the set.
        case files(extensions: Set<String>)
    }

    /// Path with a leading `~`, expanded against the scan's home folder.
    public let path: String
    public let shape: Shape
    /// Display name for `.whole` sources. `.contents` items use their own file names.
    public let label: String?
    /// The app that owns this data. When it's running the item is left unselected,
    /// because pulling a cache out from under a live app can make it misbehave.
    public let bundleID: String?

    public static func contents(of path: String, bundleID: String? = nil) -> JunkSource {
        JunkSource(path: path, shape: .contents, label: nil, bundleID: bundleID)
    }

    public static func files(in path: String, extensions: Set<String>) -> JunkSource {
        JunkSource(path: path, shape: .files(extensions: extensions), label: nil, bundleID: nil)
    }

    public static func whole(_ path: String, label: String, bundleID: String? = nil) -> JunkSource {
        JunkSource(path: path, shape: .whole, label: label, bundleID: bundleID)
    }
}
