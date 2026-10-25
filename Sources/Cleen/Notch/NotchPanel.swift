import AppKit

/// A borderless, non-activating panel pinned over the notch on every Space.
/// Non-activating so opening Cleen never steals focus from the app you're in.
final class NotchPanel: NSPanel {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        // Above the menu bar, so the panel can sit on top of it.
        level = .statusBar + 1
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }

    /// True while a panel hands the keyboard back: ordering the key panel out makes
    /// AppKit pick another of Cleen's windows (the notch on the other screen) as key,
    /// which took the keyboard away from the app it was going back to.
    static var isReleasingKeyboard = false

    // Lets text fields (search) take typing without activating the app.
    override var canBecomeKey: Bool { !Self.isReleasingKeyboard }
    override var canBecomeMain: Bool { false }
}
