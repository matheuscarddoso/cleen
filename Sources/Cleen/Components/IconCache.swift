import AppKit

/// NSWorkspace icon lookups hit the disk; lists re-render often, so remember them.
/// Usable from any thread, so lists can warm it before they appear.
nonisolated final class IconCache: @unchecked Sendable {
    static let shared = IconCache()

    private let cache = NSCache<NSURL, NSImage>()

    func icon(for url: URL) -> NSImage {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        cache.setObject(icon, forKey: url as NSURL)
        return icon
    }

    /// Looks the icon up and draws it once at list size, off the main thread, so the
    /// row that shows it later only has to composite it.
    func warm(_ url: URL, size: CGFloat = 44) {
        let icon = icon(for: url)
        var rect = CGRect(x: 0, y: 0, width: size, height: size)
        _ = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    func warm(_ urls: [URL]) async {
        await offMain { for url in urls { self.warm(url) } }
    }
}
