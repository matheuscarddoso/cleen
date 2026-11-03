import AppKit
import CleenKit
import QuickLookThumbnailing

/// The pictures on the clipboard cards, rendered once per entry and size, never on the
/// main thread. Images (pasted data and copied image files) are decoded by ImageIO at
/// the size they're drawn (see `Thumbnails`); other files are rendered by Quick Look on
/// its own queues. Everything stays in memory and on this Mac.
nonisolated final class ClipboardPreviews: @unchecked Sendable {
    static let shared = ClipboardPreviews()

    /// What to render for one card.
    struct Target: Sendable {
        let key: String
        let url: URL
        /// Decoded by ImageIO first; Quick Look only when ImageIO can't read it.
        let isImage: Bool
    }

    /// One rendering, or the fact there is none (a folder, an app, a file that's gone),
    /// so a card without a picture doesn't ask Quick Look again each time it scrolls in.
    final class Rendering: Sendable {
        let image: NSImage?

        init(image: NSImage?) {
            self.image = image
        }
    }

    private let cache = NSCache<NSString, Rendering>()

    private init() {
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    static func target(for entry: ClipboardEntry, preview: ClipboardPreview, storedImage: URL?, size: CGSize, scale: CGFloat) -> Target? {
        let key = ClipboardPreview.cacheKey(id: entry.id, size: size, scale: scale)
        switch preview.source {
        case .storedImage:
            return storedImage.map { Target(key: key, url: $0, isImage: true) }
        case let .imageFile(path):
            return Target(key: key, url: URL(filePath: path), isImage: true)
        case let .quickLook(path):
            return Target(key: key, url: URL(filePath: path), isImage: false)
        }
    }

    /// Ready to draw on this frame: rendered before, or an image already decoded big
    /// enough (prefetched when the history loaded).
    func cached(_ target: Target, size: CGSize) -> Rendering? {
        if let hit = cache.object(forKey: target.key as NSString) { return hit }
        guard target.isImage, let image = Thumbnails.shared.cached(target.url, size: size, mode: .fill) else { return nil }
        return Rendering(image: image)
    }

    /// Renders the picture, or returns nil when the card went away first; nothing
    /// half-done is cached.
    func load(_ target: Target, size: CGSize, scale: CGFloat) async -> Rendering? {
        if let hit = cached(target, size: size) { return hit }
        guard size.width > 0, size.height > 0 else { return nil }
        let url = target.url
        guard await offMain({ FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) }) else {
            return store(Rendering(image: nil), for: target)
        }
        var image: NSImage?
        if target.isImage, !Task.isCancelled {
            image = await Thumbnails.shared.load(url, size: size, mode: .fill)
        }
        if image == nil {
            image = await quickLook(url, toFill: size, scale: scale)
        }
        guard !Task.isCancelled else { return nil }
        return store(Rendering(image: image), for: target)
    }

    private func store(_ rendering: Rendering, for target: Target) -> Rendering {
        cache.setObject(rendering, forKey: target.key as NSString, cost: Self.cost(of: rendering.image))
        return rendering
    }

    /// Quick Look's thumbnail (never its generic icon: the card draws the file's own icon
    /// when there's no real preview), big enough to be cropped to `size` unstretched.
    private func quickLook(_ url: URL, toFill size: CGSize, scale: CGFloat) async -> NSImage? {
        guard !Task.isCancelled else { return nil }
        let side = ClipboardPreview.quickLookSide(toFill: size)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .thumbnail
        )
        nonisolated(unsafe) let pending = request
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                    continuation.resume(returning: representation?.nsImage)
                }
            }
        } onCancel: {
            QLThumbnailGenerator.shared.cancel(pending)
        }
    }

    private static func cost(of image: NSImage?) -> Int {
        guard let image else { return 1 }
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return rep.pixelsWide * rep.pixelsHigh * 4
        }
        return Int(image.size.width * image.size.height * 4)
    }
}
