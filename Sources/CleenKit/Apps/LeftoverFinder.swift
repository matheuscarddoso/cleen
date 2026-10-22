import Foundation

/// Finds the files an app scatters outside its bundle.
///
/// Matching is deliberately strict: exact bundle identifier, the identifier as a prefix
/// followed by a dot, or an exact folder name equal to the app's name. "Slack" matches
/// `~/Library/Application Support/Slack`; it never matches "SlackHelper Tools".
public struct LeftoverFinder: Sendable {
    let home: URL
    let systemLibrary: URL

    public init(home: URL = Paths.home, systemLibrary: URL = URL(filePath: "/Library")) {
        self.home = home
        self.systemLibrary = systemLibrary
    }

    struct Location {
        let folder: String
        let place: Leftover.Place
        /// Whether a folder named after the app (not just its bundle ID) counts here.
        let matchesByName: Bool
        let system: Bool
    }

    static let locations: [Location] = [
        Location(folder: "Library/Application Support", place: .applicationSupport, matchesByName: true, system: false),
        Location(folder: "Library/Caches", place: .caches, matchesByName: true, system: false),
        Location(folder: "Library/Preferences", place: .preferences, matchesByName: false, system: false),
        Location(folder: "Library/Preferences/ByHost", place: .preferences, matchesByName: false, system: false),
        Location(folder: "Library/Containers", place: .containers, matchesByName: false, system: false),
        Location(folder: "Library/Group Containers", place: .groupContainers, matchesByName: false, system: false),
        Location(folder: "Library/Saved Application State", place: .savedState, matchesByName: false, system: false),
        Location(folder: "Library/Logs", place: .logs, matchesByName: true, system: false),
        Location(folder: "Library/HTTPStorages", place: .webData, matchesByName: false, system: false),
        Location(folder: "Library/WebKit", place: .webData, matchesByName: false, system: false),
        Location(folder: "Library/Cookies", place: .cookies, matchesByName: false, system: false),
        Location(folder: "Library/Application Scripts", place: .scripts, matchesByName: false, system: false),
        Location(folder: "Library/LaunchAgents", place: .launchAgents, matchesByName: false, system: false),
        Location(folder: "LaunchAgents", place: .systemLaunch, matchesByName: false, system: true),
        Location(folder: "LaunchDaemons", place: .systemLaunch, matchesByName: false, system: true),
        Location(folder: "PrivilegedHelperTools", place: .helpers, matchesByName: false, system: true),
    ]

    public func leftovers(for app: InstalledApp) -> [Leftover] {
        leftovers(bundleID: app.bundleID, names: app.matchNames)
    }

    public func leftovers(bundleID: String, names: [String]) -> [Leftover] {
        let manager = FileManager.default
        // Short or generic names ("App", "Go") would catch unrelated folders.
        let names = Set(names.filter { $0.count >= 4 })
        var found: [Leftover] = []

        for location in Self.locations {
            let base = location.system ? systemLibrary : home
            let folder = base.appending(path: location.folder, directoryHint: .isDirectory)
            guard let children = try? manager.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) else { continue }
            for child in children where Self.matches(child, bundleID: bundleID, names: location.matchesByName ? names : []) {
                let url = folder.appending(path: child)
                found.append(Leftover(url: url, place: location.place, size: FileSizer.allocatedSize(of: url)))
            }
        }
        return found.sorted { $0.size > $1.size }
    }

    /// `com.tinyspeck.slackmacgap`, `com.tinyspeck.slackmacgap.plist`,
    /// `com.tinyspeck.slackmacgap.savedState`, `TEAMID.com.tinyspeck.slackmacgap` all match.
    static func matches(_ fileName: String, bundleID: String, names: Set<String>) -> Bool {
        let id = bundleID.lowercased()
        let lower = fileName.lowercased()
        if lower == id || lower.hasPrefix(id + ".") { return true }
        // Group containers and ByHost prefs wrap the ID: `TEAMID.<id>` / `<id>.<UUID>.plist`.
        let wrapped = lower.split(separator: ".", maxSplits: 1)
        if wrapped.count == 2, wrapped[1] == id || wrapped[1].hasPrefix(id + ".") { return true }
        return names.contains(fileName)
    }
}
