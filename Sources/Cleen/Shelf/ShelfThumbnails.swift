import AppKit
import QuickLookThumbnailing

/// Finder-style previews for the tray: the real first page, photo or frame from Quick
/// Look, the file's icon when there's none. Quick Look renders on its own queues; the
/// icon fallback runs off the main thread. One render per file serves every tile.
nonisolated final class ShelfThumbnails: @unchecked Sendable {
    static let shared = ShelfThumbnails()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    func cached(_ url: URL) -> NSImage? {
        cache.object(forKey: url.path as NSString)
    }

    func load(_ url: URL, side: CGFloat, scale: CGFloat) async -> NSImage {
        if let hit = cached(url) { return hit }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .all
        )
        // Icon mode draws documents as pages and photos with a border, like Finder's
        // icon view, so a tray of mixed files reads as one set.
        request.iconMode = true
        let preview: NSImage? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
        let image: NSImage
        if let preview {
            image = preview
        } else {
            image = await offMain { IconCache.shared.icon(for: url) }
        }
        cache.setObject(image, forKey: url.path as NSString)
        return image
    }
}
