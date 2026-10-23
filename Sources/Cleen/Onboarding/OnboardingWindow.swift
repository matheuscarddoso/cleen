import AppKit

/// A borderless, see-through window for the tour. Unlike the notch panel it activates
/// Cleen, so Return and the arrow keys reach it.
final class OnboardingWindow: NSWindow {
    init(frame: CGRect, ignoresMouse: Bool) {
        super.init(contentRect: frame, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = ignoresMouse
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { !ignoresMouseEvents }
}
