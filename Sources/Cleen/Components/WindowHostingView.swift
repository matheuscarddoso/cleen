import AppKit
import SwiftUI

extension NSHostingView {
    /// Content for a window whose frame Cleen sets itself (the notch panel, the tour).
    ///
    /// By default a hosting view also resizes its window to fit the SwiftUI content and
    /// follows the window's safe area. Both feed back into each other: each frame of a
    /// spring that changes the content's size moved the window, the move changed the
    /// safe-area corner insets, and those invalidated the layout again, until AppKit
    /// gave up after a couple hundred passes and killed the app. Here the window's
    /// size belongs to its controller alone, and nothing is inset.
    static func filling(_ rootView: Content) -> NSHostingView<Content> {
        let view = NSHostingView(rootView: rootView)
        view.sizingOptions = []
        view.safeAreaRegions = []
        return view
    }
}
