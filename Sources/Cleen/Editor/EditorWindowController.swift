import AppKit
import SwiftUI

/// The editor in a window of its own, as Screen Studio opens one after each take. Dark
/// like a video editor; closing it saves the project.
final class EditorWindowController: NSObject, NSWindowDelegate {
    let model: EditorModel
    private let window: NSWindow
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
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.close()
        onClose()
    }
}
