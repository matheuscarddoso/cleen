import AppKit
import ImageIO

/// macOS's own wallpapers for the background, Screen Studio's "macOS" set: the ones
/// whose full picture is on disk (the rest are downloaded on demand by the system).
nonisolated enum WallpaperLibrary {
    private static let root = URL(filePath: "/System/Library/Desktop Pictures", directoryHint: .isDirectory)

    static func pictures() -> [URL] {
        let manager = FileManager.default
        var found: [URL] = []
        let top = (try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        found += top.filter { $0.pathExtension.lowercased() == "heic" }
        let nested = root.appending(path: ".wallpapers", directoryHint: .isDirectory)
        for folder in (try? manager.contentsOfDirectory(at: nested, includingPropertiesForKeys: nil)) ?? [] {
            let files = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            found += files.filter { $0.pathExtension.lowercased() == "heic" && !$0.lastPathComponent.contains("Thumbnail") }
        }
        return found.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// A small square-ish preview, decoded without reading the whole picture.
    static func thumbnail(_ url: URL, side: Int = 120) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: side * 2,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
