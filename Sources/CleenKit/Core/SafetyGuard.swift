import Foundation

/// The last line of defense before anything is deleted or trashed.
///
/// Every removal in Cleen goes through ``validate(_:)``. Scanners already produce safe
/// candidates; this exists so that a bug in a scanner, a bad setting or a symlink trick
/// can never take out a folder whose loss would hurt.
public struct SafetyGuard: Sendable {
    public enum Violation: Error, Equatable, LocalizedError {
        case notAbsolute(String)
        case protectedLocation(String)
        case outsideAllowedRoots(String)

        public var errorDescription: String? {
            switch self {
            case .notAbsolute(let path): "Caminho inválido: \(path)"
            case .protectedLocation(let path): "Pasta protegida, não pode ser removida: \(path)"
            case .outsideAllowedRoots(let path): "Fora das áreas que o Cleen pode limpar: \(path)"
            }
        }
    }

    let home: String
    private let protected: Set<String>

    public static let standard = SafetyGuard(home: Paths.home)

    public init(home: URL) {
        let home = home.standardizedFileURL.resolvingSymlinksInPath()
            .path(percentEncoded: false).trimmingSuffix("/")
        self.home = home

        // Removing any of these would wreck the account or the system. Their *contents*
        // may still be candidates (a single cache folder, one file in Downloads).
        let homeChildren = [
            "", "/Library", "/Desktop", "/Documents", "/Downloads", "/Movies", "/Music",
            "/Pictures", "/Public", "/Applications", "/Developer", "/Projects", "/.Trash",
            "/.ssh", "/.gnupg", "/.config", "/.local", "/.cache", "/.npm", "/.bun", "/.cargo",
            "/.gradle", "/.composer", "/Library/Caches", "/Library/Logs",
            "/Library/Application Support", "/Library/Preferences", "/Library/Containers",
            "/Library/Group Containers", "/Library/Developer", "/Library/Developer/Xcode",
            "/Library/Developer/CoreSimulator", "/Library/Mobile Documents", "/Library/Mail",
            "/Library/Messages", "/Library/Photos", "/Library/Keychains", "/Library/LaunchAgents",
            "/Library/Saved Application State", "/Library/CloudStorage",
        ].map { home + $0 }

        let system = [
            "/", "/Applications", "/Library", "/System", "/Users", "/Volumes", "/bin", "/sbin",
            "/usr", "/opt", "/private", "/private/var", "/private/tmp", "/private/etc", "/etc",
            "/var", "/tmp", "/cores", "/Library/LaunchAgents", "/Library/LaunchDaemons",
            "/Library/PrivilegedHelperTools", "/Library/Application Support", "/Library/Caches",
            "/opt/homebrew",
        ]
        protected = Set(homeChildren + system)
    }

    /// Places Cleen is ever allowed to remove something from.
    private var allowedRoots: [String] {
        [
            home,
            "/Applications",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/Library/PrivilegedHelperTools",
        ]
    }

    /// Folders whose direct children are synced to a server: trashing one (the iCloud
    /// Drive root, an app's iCloud container, a Dropbox or OneDrive folder) deletes it
    /// in the cloud and on every other device too.
    private var syncedParents: [String] {
        [home + "/Library/Mobile Documents", home + "/Library/CloudStorage"]
    }

    @discardableResult
    public func validate(_ url: URL) throws(Violation) -> URL {
        var url = url
        var raw = url.path(percentEncoded: false)
        guard raw.hasPrefix("/") else { throw .notAbsolute(raw) }
        // The whole-disk map walks the Data volume, where /Users/… shows up as
        // /System/Volumes/Data/Users/…: the same files, judged by their usual path.
        let dataVolume = "/System/Volumes/Data"
        if raw.hasPrefix(dataVolume + "/") {
            raw = String(raw.dropFirst(dataVolume.count))
            url = URL(filePath: raw)
        }

        // Resolve symlinks in the *parent* only: removing a link must remove the link,
        // but a link elsewhere in the path must not smuggle us into a protected place.
        let standardized = url.standardizedFileURL
        let parent = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
        let resolved = parent.appending(path: standardized.lastPathComponent)
            .path(percentEncoded: false).trimmingSuffix("/")

        for candidate in [standardized.path(percentEncoded: false).trimmingSuffix("/"), resolved] {
            if protected.contains(candidate) || candidate.hasPrefix("/System/") {
                throw .protectedLocation(candidate)
            }
            let parentPath = (candidate as NSString).deletingLastPathComponent
            // A whole Photos library goes through Photos, never the Lixo.
            if syncedParents.contains(parentPath) || candidate.hasSuffix(".photoslibrary") {
                throw .protectedLocation(candidate)
            }
        }

        let inside = allowedRoots.contains { resolved.hasPrefix($0 + "/") }
        guard inside else { throw .outsideAllowedRoots(resolved) }

        // Inside /Applications only app bundles and loose files (a forgotten .dmg) may go;
        // folders like /Applications/Utilities hold other apps.
        if resolved.hasPrefix("/Applications/"), !resolved.hasSuffix(".app") {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: resolved, isDirectory: &isDirectory)
            let depth = resolved.split(separator: "/").count
            if depth <= 2, exists, isDirectory.boolValue { throw .protectedLocation(resolved) }
        }
        return URL(filePath: resolved)
    }
}
