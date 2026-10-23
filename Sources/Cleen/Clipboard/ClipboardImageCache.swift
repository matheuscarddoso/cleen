import AppKit

/// Decoded clipboard images, so scrolling the list doesn't reread PNGs from disk.
final class ClipboardImageCache {
    static let shared = ClipboardImageCache()
    private let cache = NSCache<NSURL, NSImage>()

    func image(at url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
