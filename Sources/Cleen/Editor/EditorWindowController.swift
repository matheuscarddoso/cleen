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
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        window.title = model.name
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = CGSize(width: 980, height: 640)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView().environment(model).injecting(app))
        window.center()
        window.setFrameAutosaveName("CleenEditor")
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
