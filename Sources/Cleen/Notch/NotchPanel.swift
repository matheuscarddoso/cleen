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
        // Handing the keyboard back orders the panel out and straight back in; with the
        // system's window fade that showed as the whole panel going translucent instead
        // of the shape closing into the notch.
        animationBehavior = .none
    }

    /// Whether the panel may take the keyboard (search, notes, a text field): only
    /// while it's open. A closed notch that could become key
    /// gets picked by AppKit as the next key window when another panel gives the keyboard
    /// up (the one on the other screen did, a moment after a paste), and then typing went
    /// to Cleen instead of back to the app you were in.
    var acceptsKeyboard: () -> Bool = { false }

    override var canBecomeKey: Bool { acceptsKeyboard() }

    /// Taking the keyboard makes Cleen the active app, as Raycast does when it opens:
    /// the app you were in then steps back properly, so handing activation back to it
    /// (`PasteKeystroke.handBack`) puts its window and the field with the cursor back.
    override func becomeKey() {
        super.becomeKey()
        if !NSApp.isActive { NSApp.activate() }
    }

    override var canBecomeMain: Bool { false }
}
