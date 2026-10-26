import AppKit
import SwiftUI

/// The editor in a window of its own, as Screen Studio opens one after each take. Dark
/// like a video editor; closing it saves the project.
final class EditorWindowController: NSObject, NSWindowDelegate {
    let model: EditorModel
    private let window: NSWindow
    private var keyMonitor: Any?
    var onClose: () -> Void = {}

    init?(folder: URL, app: AppModel) {
        guard let model = EditorModel(folder: folder) else { return nil }
        self.model = model
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        window.title = model.name
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // A compact toolbar gives the window macOS 26's 20.5 pt corners, concentric with
        // Export (8 pt, inset 12.5 pt); the window buttons are moved to the middle of
        // the editor's taller bar (see `centerWindowButtons`).
        window.toolbar = NSToolbar(identifier: "CleenEditor")
        window.toolbarStyle = .unifiedCompact
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 6 / 255, green: 8 / 255, blue: 13 / 255, alpha: 1)
        window.minSize = CGSize(width: 1100, height: 660)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView().environment(model).injecting(app))
        window.center()
        window.setFrameAutosaveName("CleenEditorWindow")
        installKeys()
    }

    /// The editor's keys, Screen Studio's: they work wherever the focus is in the
    /// window (a slider, a button), except while typing in a field.
    private func installKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            if event.type == .flagsChanged {
                // Holding ⌥ takes the scissors out; letting go puts them away.
                let held = event.modifierFlags.contains(.option)
                if self.model.isCuttingHeld != held { self.model.isCuttingHeld = held }
                return event
            }
            if self.window.firstResponder is NSText { return event }
            return EditorKeys.handle(event, editor: self.model) ? nil : event
        }
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        centerWindowButtons()
    }

    /// The close, minimize and zoom buttons, centered in the editor's title bar instead of
    /// macOS's shorter one. AppKit lays them out again on resizes and focus changes, so
    /// this runs after each.
    private func centerWindowButtons() {
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(kind), let container = button.superview else { continue }
            let fromTop = EditorTopBar.height / 2 - button.frame.height / 2
            let y = container.isFlipped ? fromTop : container.bounds.height - fromTop - button.frame.height
            if abs(button.frame.origin.y - y) > 0.5 { button.setFrameOrigin(CGPoint(x: button.frame.origin.x, y: y)) }
        }
    }

    func windowDidResize(_ notification: Notification) { centerWindowButtons() }
    func windowDidEndLiveResize(_ notification: Notification) { centerWindowButtons() }
    func windowDidBecomeKey(_ notification: Notification) { centerWindowButtons() }
    func windowDidExitFullScreen(_ notification: Notification) { centerWindowButtons() }

    func windowDidResignKey(_ notification: Notification) {
        model.isCuttingHeld = false
        centerWindowButtons()
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        model.close()
        onClose()
    }
}
