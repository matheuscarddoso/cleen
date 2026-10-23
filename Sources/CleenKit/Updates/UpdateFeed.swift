import Foundation

/// What a release publishes for the updater: `appcast.json`, next to the DMG.
///
///     { "version": "1.2.0", "build": 58, "url": "https://…/Cleen-1.2.0.dmg",
///       "sha256": "…", "notes": "…", "minimumSystemVersion": "26.0" }
public struct UpdateFeed: Codable, Sendable, Equatable {
    public let version: String
    public let build: Int?
    public let url: URL
    public let sha256: String
    public let notes: String?
    public let minimumSystemVersion: String?

    public init(version: String, build: Int?, url: URL, sha256: String, notes: String?, minimumSystemVersion: String?) {
        self.version = version
        self.build = build
        self.url = url
        self.sha256 = sha256
        self.notes = notes
        self.minimumSystemVersion = minimumSystemVersion
    }

    /// Newer than what's running, and installable on this macOS.
    public func isUpdate(over current: String, system: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> Bool {
        guard AppVersion(version) > AppVersion(current) else { return false }
        guard let minimum = minimumSystemVersion else { return true }
        let running = AppVersion("\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)")
        return running >= AppVersion(minimum)
    }
}

/// "1.10.2" compared number by number (so 1.10 > 1.9), ignoring a leading "v" and
/// anything after a hyphen ("1.2.0-3-gabc" is 1.2.0).
public struct AppVersion: Comparable, Sendable {
    public let parts: [Int]

    public init(_ text: String) {
        var text = text.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("v") { text.removeFirst() }
        let core = text.split(separator: "-").first.map(String.init) ?? text
        parts = core.split(separator: ".").map { Int($0) ?? 0 }
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}
