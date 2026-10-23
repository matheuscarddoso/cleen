import AppKit
import Quartz

/// Space on the tray: the system Quick Look panel for the selected files, arrows
/// stepping through them. The notch panel doesn't activate Cleen, so this does, and
/// keeps the notch open while the preview is up.
final class ShelfQuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ShelfQuickLook()

    private var urls: [URL] = []
    private weak var notch: NotchState?
    private var heldBefore = false
    private var watch: Task<Void, Never>?

    var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    func toggle(_ urls: [URL], notch: NotchState) {
        if isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        } else {
            show(urls, notch: notch)
        }
    }

    func show(_ urls: [URL], notch: NotchState) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        if self.notch == nil {
            self.notch = notch
            heldBefore = notch.holdsOpen
            notch.holdsOpen = true
        }
        NSApp.activate()
        // The tray's view offers itself as the panel's controller through the responder
        // chain; when it isn't in the key window's chain, take the panel directly.
        panel.updateController()
        if panel.dataSource !== self {
            take(panel)
        }
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
        watchForClose()
    }

    /// Called by the tray's view when the panel picks it as controller.
    func take(_ panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.delegate = self
    }

    func release(_ panel: QLPreviewPanel) {
        if panel.dataSource === self { panel.dataSource = nil }
        if panel.delegate === self { panel.delegate = nil }
    }

    /// The panel closes itself (Space, Esc, its close button), with no callback for
    /// it, so look every so often and give the notch back when it's gone.
    private func watchForClose() {
        watch?.cancel()
        watch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard let self, !Task.isCancelled else { return }
                if !self.isVisible {
                    self.finish()
                    return
                }
            }
        }
    }

    private func finish() {
        watch = nil
        notch?.holdsOpen = heldBefore
        notch = nil
    }

    // MARK: QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}
