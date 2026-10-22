import Foundation

/// Folders that are never browsed when looking for the person's own files.
enum ScanExclusions {
    /// Bundles behave like single documents; their insides are not the person's files.
    static let packageSuffixes = [
        ".app", ".photoslibrary", ".musiclibrary", ".tvlibrary", ".imovielibrary", ".fcpbundle",
        ".logicx", ".band", ".xcodeproj", ".xcworkspace", ".xcarchive", ".bundle", ".framework",
        ".sparsebundle", ".pages", ".numbers", ".key",
    ]

    /// Dependency and VCS folders: huge, regenerable, and covered by "Projetos de código".
    static let folderNames: Set<String> = [
        "node_modules", ".git", ".svn", ".hg", "vendor", "Pods", "DerivedData", ".build",
        ".next", ".venv", "venv", ".Trash", ".cache", ".npm", ".bun", ".cargo", ".gradle",
        ".rustup", ".nvm", ".pyenv", ".docker", ".orbstack", ".cocoapods", ".m2", ".pub-cache",
        ".gem", ".vscode", ".cursor", ".swiftpm",
    ]

    static func shouldSkip(folderName name: String, level: Int, home: Bool) -> Bool {
        if folderNames.contains(name) { return true }
        if packageSuffixes.contains(where: name.hasSuffix) { return true }
        // `~/Library` is app data, not the person's files; it has its own sections.
        if home, level == 1, name == "Library" { return true }
        return false
    }
}
