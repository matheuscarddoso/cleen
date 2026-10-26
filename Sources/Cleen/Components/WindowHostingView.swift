import AppKit
import SwiftUI

extension NSHostingView {
    /// Content for a window whose frame Cleen sets itself (the notch panel, the tour).
    ///
    /// A hosting view that is a window's content view also resizes that window to fit
    /// the SwiftUI content (`updateAnimatedWindowSize`), whatever its `sizingOptions`
    /// say. That fed back into itself: each frame of a spring moved the window, the move
    /// invalidated the layout again, and AppKit killed the app after a couple hundred
    /// passes. Inside a plain container it only fills the space it's given; the window's
    /// size belongs to its controller alone.
    static func filling(_ rootView: Content) -> NSView {
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        let container = NSView()
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        return container
    }
}
