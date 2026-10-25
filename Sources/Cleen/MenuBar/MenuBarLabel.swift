import SwiftUI

/// The menu bar item: just Cleen's icon. What the Mac is up to is in its menu.
struct MenuBarLabel: View {
    var body: some View {
        Image(nsImage: Self.icon)
            .accessibilityLabel("Cleen")
    }

    /// The app icon at menu bar size, cropped to its body: the icon grid keeps it at 824 of
    /// 1024 points, and the margin around it (where the shadow falls) would only shrink it.
    private static let icon: NSImage = {
        let source = NSApp.applicationIconImage ?? NSImage()
        let inset = source.size.width * 100 / 1024
        return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            source.draw(in: rect, from: NSRect(origin: .zero, size: source.size).insetBy(dx: inset, dy: inset), operation: .sourceOver, fraction: 1)
            return true
        }
    }()
}
