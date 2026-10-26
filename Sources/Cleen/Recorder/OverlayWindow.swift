import AppKit
import SwiftUI

/// A borderless, see-through window on one screen for the recorder's on-screen helpers
/// (area picker, highlight, countdown, camera preview, desktop cover).
final class OverlayWindow: NSPanel {
    init(frame: CGRect, level: NSWindow.Level, ignoresMouse: Bool, content: some View) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = ignoresMouse
        contentView = NSHostingView.filling(content)
    }

    override var canBecomeKey: Bool { !ignoresMouseEvents }
}
