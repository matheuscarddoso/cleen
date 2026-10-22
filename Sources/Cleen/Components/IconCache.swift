import AppKit

/// NSWorkspace icon lookups hit the disk; lists re-render often, so remember them.
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSURL, NSImage>()

    func icon(for url: URL) -> NSImage {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        cache.setObject(icon, forKey: url as NSURL)
        return icon
    }
}
