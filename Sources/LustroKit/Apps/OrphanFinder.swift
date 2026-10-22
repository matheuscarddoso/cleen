import AppKit
import Foundation

/// Finds data left behind by apps that were deleted by dragging them to the Trash.
public struct OrphanFinder: Sendable {
    let home: URL
    /// Returns true when some installed app (or helper) owns the identifier.
    let isInstalled: @Sendable (String) -> Bool

    public init(home: URL = Paths.home, installedBundleIDs: Set<String>) {
        self.home = home
        let installed = Set(installedBundleIDs.map { $0.lowercased() })
        self.isInstalled = { candidate in
            let id = candidate.lowercased()
            if installed.contains(id) { return true }
            // Helpers and extensions extend their app's ID (`com.google.Chrome.helper`);
            // and an app may extend a shared vendor prefix the data uses.
            if installed.contains(where: { id.hasPrefix($0 + ".") || $0.hasPrefix(id + ".") }) { return true }
            // Same vendor (`com.microsoft.autoupdate` while Teams is installed): shared
            // updaters and frameworks live under the vendor's prefix. Err on keeping them.
            let vendor = id.split(separator: ".").prefix(2).joined(separator: ".") + "."
            if installed.contains(where: { $0.hasPrefix(vendor) }) { return true }
            // Last resort: ask Launch Services, which also knows apps outside /Applications.
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) != nil
        }
    }

    /// Folders scanned and the suffixes their entries carry after the bundle ID.
    static let locations: [(folder: String, place: Leftover.Place, suffixes: [String])] = [
        ("Library/Application Support", .applicationSupport, []),
        ("Library/Caches", .caches, []),
        ("Library/Preferences", .preferences, [".plist"]),
        ("Library/Containers", .containers, []),
        ("Library/Saved Application State", .savedState, [".savedState"]),
        ("Library/HTTPStorages", .webData, [".binarycookies"]),
        ("Library/WebKit", .webData, []),
        ("Library/Cookies", .cookies, [".binarycookies"]),
        ("Library/Logs", .logs, []),
    ]

    static let appEvidence: Set<Leftover.Place> = [.savedState, .containers, .webData, .cookies]

    public func scan() -> [OrphanGroup] {
        let manager = FileManager.default
        var byID: [String: [Leftover]] = [:]

        for location in Self.locations {
            let folder = home.appending(path: location.folder, directoryHint: .isDirectory)
            guard let children = try? manager.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) else { continue }
            for child in children {
                if Task.isCancelled { return [] }
                guard let id = Self.bundleID(from: child, suffixes: location.suffixes), !isInstalled(id) else { continue }
                let url = folder.appending(path: child)
                let size = FileSizer.allocatedSize(of: url)
                guard size > 0 else { continue }
                byID[id.lowercased(), default: []].append(Leftover(url: url, place: location.place, size: size))
            }
        }
        return byID
            // Only identifiers with traces a real app leaves (window state, a sandbox
            // container, web storage) count. Command-line tools also write reverse-DNS
            // caches and prefs, and they were never "installed" in a way we can see.
            .filter { $0.value.contains { Self.appEvidence.contains($0.place) } }
            .map { OrphanGroup(bundleID: $0.key, items: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.totalSize > $1.totalSize }
    }

    /// Extracts a reverse-DNS app identifier from a file name, or nil when the name
    /// doesn't look like one. Apple's own identifiers are never treated as orphans:
    /// system components come and go with macOS itself.
    static func bundleID(from fileName: String, suffixes: [String]) -> String? {
        var name = fileName
        for suffix in suffixes where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } }),
              ["com", "org", "net", "io", "app", "dev", "co", "me", "us", "de", "jp", "ru", "br", "uk", "fr", "ch", "nl", "info", "company", "cc", "tv", "ai", "so", "sh", "md"]
                .contains(parts[0].lowercased())
        else { return nil }
        let lower = name.lowercased()
        if lower.hasPrefix("com.apple.") || lower.hasPrefix("group.") { return nil }
        return name
    }
}
