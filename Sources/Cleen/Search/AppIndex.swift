import AppKit

/// The apps the search can open: everything in the usual Applications folders, with the
/// names Finder shows (localized: "Calculadora", not "Calculator.app").
struct AppEntry: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    var id: String { url.path(percentEncoded: false) }
}

enum AppIndex {
    private nonisolated static let folders = [
        "/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
        "/System/Library/CoreServices/Applications",
    ].map { URL(filePath: $0) } + [URL.homeDirectory.appending(path: "Applications")]

    /// Blocking (a few milliseconds); call it off the main thread.
    nonisolated static func scan() -> [AppEntry] {
        let files = FileManager.default
        var seen = Set<String>()
        var apps: [AppEntry] = []
        // Finder isn't in a folder of apps, but it's opened from launchers all the time.
        let extras = [URL(filePath: "/System/Library/CoreServices/Finder.app")]
        let found = folders.flatMap { folder in
            // Not `.skipsHiddenFiles`: Safari is a hidden-flagged link into the system's
            // cryptex, and it would vanish with it.
            (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        } + extras
        for url in found where url.pathExtension == "app" && !url.lastPathComponent.hasPrefix(".") {
            let name = files.displayName(atPath: url.path(percentEncoded: false)).replacingOccurrences(of: ".app", with: "")
            guard seen.insert(name).inserted else { continue }
            apps.append(AppEntry(url: url, name: name))
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
