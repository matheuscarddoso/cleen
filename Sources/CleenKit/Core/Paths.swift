import Foundation

public enum Paths {
    public static let home = URL.homeDirectory.standardizedFileURL

    /// Expands a leading `~` against `home`. Absolute paths pass through untouched.
    public static func expand(_ path: String, home: URL = Paths.home) -> URL {
        if path == "~" { return home }
        if path.hasPrefix("~/") {
            return home.appending(path: String(path.dropFirst(2)), directoryHint: .inferFromPath)
        }
        return URL(filePath: path)
    }

    /// `/Users/me/Library/Caches` → `~/Library/Caches`, for display.
    public static func abbreviate(_ url: URL, home: URL = Paths.home) -> String {
        let path = url.path(percentEncoded: false)
        let homePath = home.path(percentEncoded: false).trimmingSuffix("/")
        if path == homePath { return "~" }
        if path.hasPrefix(homePath + "/") { return "~" + path.dropFirst(homePath.count) }
        return path
    }

    /// Whether `url` sits strictly inside `ancestor`.
    public static func isDescendant(_ url: URL, of ancestor: URL) -> Bool {
        let child = url.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
        let parent = ancestor.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
        return child.hasPrefix(parent + "/")
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        guard count > suffix.count, hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}
