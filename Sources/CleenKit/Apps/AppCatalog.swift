import CoreServices
import Foundation

public enum AppCatalog {
    public static func defaultFolders(home: URL = Paths.home) -> [URL] {
        [URL(filePath: "/Applications", directoryHint: .isDirectory), home.appending(path: "Applications")]
    }

    /// App bundles in the given folders and one level of subfolders
    /// (`/Applications/Utilities`, vendor folders like `/Applications/Microsoft Office`).
    public static func bundles(in folders: [URL] = defaultFolders()) -> [URL] {
        let manager = FileManager.default
        var found: [URL] = []
        for folder in folders {
            let children = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for child in children {
                if child.pathExtension == "app" {
                    found.append(child)
                } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    let nested = (try? manager.contentsOfDirectory(at: child, includingPropertiesForKeys: nil)) ?? []
                    found += nested.filter { $0.pathExtension == "app" }
                }
            }
        }
        return found
    }

    /// Reads one bundle. Sizing is the slow part, so callers fan this out.
    public static func load(_ url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        let info = bundle.infoDictionary ?? [:]
        let fileName = url.deletingPathExtension().lastPathComponent
        let bundleNames = [info["CFBundleName"], info["CFBundleDisplayName"]].compactMap { $0 as? String }

        let path = url.path(percentEncoded: false)
        var owner = stat()
        let ownedByRoot = lstat(path, &owner) == 0 && owner.st_uid == 0
        let isAppStore = FileSizer.exists(url.appending(path: "Contents/_MASReceipt"))
        // Safari and friends live on the sealed system volume behind a symlink.
        let isSystem = url.resolvingSymlinksInPath().path(percentEncoded: false).hasPrefix("/System/")
            || (bundleID.hasPrefix("com.apple.") && ownedByRoot && !isAppStore)

        return InstalledApp(
            url: url,
            name: fileName,
            matchNames: Array(Set([fileName] + bundleNames)),
            bundleID: bundleID,
            version: info["CFBundleShortVersionString"] as? String,
            size: FileSizer.allocatedSize(of: url),
            lastUsed: lastUsed(url),
            isAppStore: isAppStore,
            isSystem: isSystem,
            needsAdministrator: ownedByRoot || !FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path(percentEncoded: false))
        )
    }

    /// Spotlight's record of the last launch, when it has one.
    static func lastUsed(_ url: URL) -> Date? {
        guard let item = MDItemCreate(kCFAllocatorDefault, url.path(percentEncoded: false) as CFString) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
