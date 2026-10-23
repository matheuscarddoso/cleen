import Foundation

/// Where the icons come from: the `lucide-static` npm package on unpkg, always pinned to
/// one version so the font, the code points and the SVGs agree with each other.
public enum LucideSource {
    /// The files the icon tab needs, downloaded once per version: remote path → file name
    /// in the cache folder.
    public static let files: [(remote: String, local: String)] = [
        ("font/info.json", infoFile),
        ("tags.json", tagsFile),
        ("font/lucide.ttf", fontFile),
    ]
    public static let infoFile = "info.json"
    public static let tagsFile = "tags.json"
    public static let fontFile = "lucide.ttf"

    /// Rough sizes (version 1.61), for the download's progress when the server doesn't
    /// say how big a file is.
    public static let expectedBytes: [String: Int] = [
        infoFile: 300_000,
        tagsFile: 280_000,
        fontFile: 930_000,
    ]

    /// How often to ask whether a newer Lucide came out.
    public static let checkInterval: TimeInterval = 7 * 86_400

    /// unpkg answers `@latest` with a redirect to the exact version; the redirect alone
    /// says which one, so this small file is never actually downloaded.
    public static let latestProbeURL = URL(string: "https://unpkg.com/lucide-static@latest/package.json")!

    public static func fileURL(version: String, path: String) -> URL {
        URL(string: "https://unpkg.com/lucide-static@\(version)/\(path)")!
    }

    public static func svgURL(version: String, name: String) -> URL {
        fileURL(version: version, path: "icons/\(name).svg")
    }

    /// "1.61.0" out of a redirect such as `/lucide-static@1.61.0/package.json`.
    public static func version(fromLocation location: String) -> String? {
        guard let at = location.range(of: "lucide-static@") else { return nil }
        let version = location[at.upperBound...].prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        guard let first = version.first, first.isNumber,
              version.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" })
        else { return nil }
        return String(version)
    }

    /// Compares dotted versions numerically: "1.10.0" is newer than "1.9.3".
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = numbers(candidate), b = numbers(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    public static func needsCheck(lastChecked: Date?, now: Date = .now) -> Bool {
        guard let lastChecked else { return true }
        // A clock set back shouldn't hold the check off for months.
        return now.timeIntervalSince(lastChecked) >= checkInterval || lastChecked > now
    }

    private static func numbers(_ version: String) -> [Int] {
        version.prefix { $0 != "-" }.split(separator: ".").map { Int($0) ?? 0 }
    }
}
