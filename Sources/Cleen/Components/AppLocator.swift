import AppKit

/// Where an app lives, by bundle id. A Launch Services lookup per card per render
/// (hover included) added up; the answer doesn't change while Cleen runs.
enum AppLocator {
    private static var known: [String: URL?] = [:]

    static func url(for bundleID: String) -> URL? {
        if let hit = known[bundleID] { return hit }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        known[bundleID] = url
        return url
    }
}
