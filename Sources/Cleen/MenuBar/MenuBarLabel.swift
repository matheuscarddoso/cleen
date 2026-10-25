import SwiftUI

/// The menu bar item: just Cleen's mascot, in color. What the Mac is up to is in its menu.
struct MenuBarLabel: View {
    var body: some View {
        // In color: on its own, the label's image would be drawn as a template.
        Image(nsImage: Self.icon)
            .renderingMode(.original)
            .accessibilityLabel("Cleen")
    }

    /// The mascot (see scripts/make-menubar-icon.swift) 16 pt tall, as tall as the
    /// system's own symbols up there; the app icon if it's missing (a bare `swift run`).
    private static let icon: NSImage = {
        let image = Bundle.main.image(forResource: "MenuBarIcon").map { mascot -> NSImage in
            mascot.size = NSSize(width: 16 * mascot.size.width / max(1, mascot.size.height), height: 16)
            return mascot
        } ?? NSApp.applicationIconImage.map { source -> NSImage in
            NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                source.draw(in: rect)
                return true
            }
        } ?? NSImage()
        image.isTemplate = false
        return image
    }()
}
