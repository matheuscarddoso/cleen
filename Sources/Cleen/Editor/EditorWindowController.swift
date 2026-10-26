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
        // An empty unified toolbar makes the title bar as tall as the editor's own (52 pt)
        // and centers the window buttons in it.
        window.toolbar = NSToolbar(identifier: "CleenEditor")
        window.toolbarStyle = .unified
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
    }

    func windowDidResignKey(_ notification: Notification) {
        model.isCuttingHeld = false
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        model.close()
        onClose()
    }
}
