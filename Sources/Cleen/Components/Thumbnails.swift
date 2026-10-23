import AppKit
import ImageIO

/// Screenshots and copied images decoded at the size they're drawn, off the main thread.
///
/// Captures are full Retina PNGs (3000 px and up). Handing one to a 66 pt tile made the
/// main thread decode all of it during the tab switch, once per image. ImageIO scales
/// while decoding, on a background queue, to at least the pixels the frame needs on the
/// sharpest screen attached, so what's drawn is the same. One decode per file serves
/// every frame it's big enough for.
nonisolated final class Thumbnails: @unchecked Sendable {
    static let shared = Thumbnails()

    /// How the image sits in its frame, which decides the pixels it needs.
    enum Mode: Sendable {
        case fit
        case fill
    }

    /// Longest side decoded ahead of time: covers the tiles, the cards and the 210 pt
    /// preview at 2×.
    static let prefetchPixels: CGFloat = 640

    private final class Entry {
        let image: NSImage
        /// Longest side of the decoded image, and of the file itself, in pixels.
        let pixels: CGFloat
        let sourceSize: CGSize

        init(image: NSImage, pixels: CGFloat, sourceSize: CGSize) {
            self.image = image
            self.pixels = pixels
            self.sourceSize = sourceSize
        }
    }

    private let cache = NSCache<NSString, Entry>()
    private let lock = NSLock()
    private var _scale: CGFloat = 2

    private init() {
        cache.totalCostLimit = 192 * 1024 * 1024
    }

    /// The sharpest attached screen's scale; set from the main thread.
    var scale: CGFloat {
        get { lock.withLock { _scale } }
        set { lock.withLock { _scale = newValue } }
    }

    func cached(_ url: URL, size: CGSize, mode: Mode) -> NSImage? {
        guard let entry = cache.object(forKey: url.path as NSString) else { return nil }
        let needed = Self.pixels(for: entry.sourceSize, in: size, mode: mode, scale: scale)
        return entry.pixels >= needed ? entry.image : nil
    }

    func load(_ url: URL, size: CGSize, mode: Mode) async -> NSImage? {
        if let hit = cached(url, size: size, mode: mode) { return hit }
        return await offMain {
            self.decode(url) { source in Self.pixels(for: source, in: size, mode: mode, scale: self.scale) }
        }
    }

    /// Decodes ahead of time, so the first look at a tab finds them ready.
    func prefetch(_ urls: [URL]) {
        let pending = urls.filter { cache.object(forKey: $0.path as NSString) == nil }
        guard !pending.isEmpty else { return }
        Task.detached(priority: .utility) {
            for url in pending {
                _ = await offMain { self.decode(url) { _ in Self.prefetchPixels } }
            }
        }
    }

    // MARK: Decoding

    private func decode(_ url: URL, pixels wanted: (CGSize) -> CGFloat) -> NSImage? {
        let cacheKey = url.path as NSString
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0
        else { return nil }
        let sourceSize = CGSize(width: width, height: height)
        let longest = max(width, height)
        let target = min(longest, wanted(sourceSize))
        if let entry = cache.object(forKey: cacheKey), entry.pixels >= target { return entry.image }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: target,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
        let entry = Entry(image: image, pixels: CGFloat(max(cgImage.width, cgImage.height)), sourceSize: sourceSize)
        cache.setObject(entry, forKey: cacheKey, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    /// The longest side, in pixels, the image needs to be drawn sharp in a frame of
    /// `size` points, placed the way scaledToFit/scaledToFill would.
    private static func pixels(for source: CGSize, in size: CGSize, mode: Mode, scale: CGFloat) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return .greatestFiniteMagnitude }
        let ratio = mode == .fill
            ? max(size.width / source.width, size.height / source.height)
            : min(size.width / source.width, size.height / source.height)
        return min(max(source.width, source.height), ceil(max(source.width, source.height) * ratio * scale))
    }
}
