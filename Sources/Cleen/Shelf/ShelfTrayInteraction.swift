import AppKit
import CleenKit
import Quartz
import SwiftUI

/// What the pointer is over in the tray.
enum ShelfHoverTarget: Equatable {
    case file(URL)
    case add
}

/// The tray's hands. SwiftUI draws the tiles; this AppKit layer on top takes every
/// click, because SwiftUI can't drag several files out at once, draw a rubber band, or
/// tell a ⌘-click from a ⇧-click. It hit-tests against the tile frames SwiftUI reports.
struct ShelfTrayInteraction: NSViewRepresentable {
    let shelf: ShelfModel
    let notch: NotchState
    let frames: [URL: CGRect]
    let addFrame: CGRect?
    let onBand: (CGRect?) -> Void
    let onHover: (ShelfHoverTarget?) -> Void

    func makeNSView(context: Context) -> ShelfTrayView {
        ShelfTrayView()
    }

    func updateNSView(_ view: ShelfTrayView, context: Context) {
        view.shelf = shelf
        view.notch = notch
        view.addFrame = addFrame
        view.onBand = onBand
        view.onHover = onHover
        view.frames = frames
    }
}

final class ShelfTrayView: NSView, NSMenuDelegate, NSViewToolTipOwner {
    var shelf: ShelfModel?
    var notch: NotchState?
    var addFrame: CGRect?
    var onBand: (CGRect?) -> Void = { _ in }
    var onHover: (ShelfHoverTarget?) -> Void = { _ in }
    var frames: [URL: CGRect] = [:] {
        didSet {
            guard frames != oldValue else { return }
            removeAllToolTips()
            for frame in frames.values {
                addToolTip(frame, owner: self, userData: nil)
            }
        }
    }

    /// What the mouse went down on, deciding what a drag and the release mean.
    private enum Press {
        case none
        /// `selectOnRelease`: a plain click on an already-selected file waits for the
        /// release to narrow the selection, so the whole selection can still be dragged.
        case file(URL, selectOnRelease: Bool)
        case add
        case empty(mode: ShelfSelection<URL>.Mode, hadSelection: Bool)
    }

    private var press = Press.none
    private var downPoint = CGPoint.zero
    private var isBanding = false
    private var hovered: ShelfHoverTarget?
    private var sharePicker: NSSharingServicePicker?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    // The panel never activates Cleen; the first click should act, not just focus.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Keys reach the tray as soon as the panel is key, without a click first.
        if let window { window.makeFirstResponder(self) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    // MARK: Hit testing

    private func file(at point: CGPoint) -> URL? {
        frames.first { $0.value.contains(point) }?.key
    }

    private func target(at point: CGPoint) -> ShelfHoverTarget? {
        if let url = file(at: point) { return .file(url) }
        if let addFrame, addFrame.contains(point) { return .add }
        return nil
    }

    private func setHovered(_ target: ShelfHoverTarget?) {
        guard target != hovered else { return }
        hovered = target
        onHover(target)
    }

    private static func mode(_ flags: NSEvent.ModifierFlags) -> ShelfSelection<URL>.Mode {
        if flags.contains(.command) { return .toggle }
        if flags.contains(.shift) { return .extend }
        return .replace
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        setHovered(target(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard let shelf else { return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        downPoint = point
        let mode = Self.mode(event.modifierFlags)
        switch target(at: point) {
        case .file(let url):
            if event.clickCount >= 2, mode == .replace {
                shelf.open(shelf.selection.contains(url) ? shelf.selectedURLs : [url])
                press = .none
            } else if mode == .replace, shelf.selection.contains(url) {
                press = .file(url, selectOnRelease: true)
            } else {
                shelf.selection.click(url, mode: mode, in: shelf.urls)
                press = .file(url, selectOnRelease: false)
            }
        case .add:
            press = .add
        case nil:
            press = .empty(mode: mode, hadSelection: !shelf.selection.isEmpty)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let shelf else { return }
        let point = convert(event.locationInWindow, from: nil)
        let distance = hypot(point.x - downPoint.x, point.y - downPoint.y)
        switch press {
        case .file(let url, _):
            guard distance > 3 else { return }
            press = .none
            // A ⌘-click that just unselected it drags nothing.
            guard shelf.selection.contains(url) else { return }
            beginDrag(shelf.selectedURLs, event: event)
        case .empty(let mode, _):
            if !isBanding {
                guard distance > 2 else { return }
                isBanding = true
                shelf.selection.beginBand(mode: mode)
            }
            let band = ShelfSelection<URL>.band(from: downPoint, to: point).intersection(bounds)
            shelf.selection.updateBand(touching: ShelfSelection.touched(by: band, frames: frames), mode: mode)
            onBand(band)
            autoscroll(with: event)
        case .none, .add:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            press = .none
            if isBanding {
                isBanding = false
                onBand(nil)
            }
        }
        guard let shelf, let notch else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch press {
        case .file(let url, true):
            shelf.selection.click(url, mode: .replace, in: shelf.urls)
        case .add:
            if target(at: point) == .add { choose(shelf, notch) }
        case .empty(.replace, let hadSelection) where !isBanding:
            // Like Finder, a click on empty space lets go of the selection; with
            // nothing selected, it's the way in for adding files without dragging.
            if hadSelection {
                shelf.selection.clear()
            } else {
                choose(shelf, notch)
            }
        default:
            break
        }
    }

    /// The picker runs its own modal loop; start it after this click has finished.
    private func choose(_ shelf: ShelfModel, _ notch: NotchState) {
        Task { shelf.choose(holdingOpen: notch) }
    }

    override func scrollWheel(with event: NSEvent) {
        // The tray scrolls sideways under this layer; hand the gesture down to it.
        if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    // MARK: Dragging out

    private func beginDrag(_ urls: [URL], event: NSEvent) {
        guard !urls.isEmpty else { return }
        let items = urls.map { url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let tile = frames[url] ?? CGRect(origin: downPoint, size: .zero)
            let image = ShelfThumbnails.shared.cached(url) ?? IconCache.shared.icon(for: url)
            item.setDraggingFrame(ShelfFileTile.Metrics.thumbnailFrame(in: tile), contents: image)
            return item
        }
        guard let shelf else { return }
        let source = ShelfDragSource(shelf: shelf, notch: notch, urls: urls)
        let session = beginDraggingSession(with: items, event: event, source: source)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = urls.count > 1 ? .pile : .none
    }

    /// The full path, so two files with the same name can be told apart.
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        file(at: point)?.path(percentEncoded: false) ?? ""
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if handleKey(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self, handleKey(event) else { return super.performKeyEquivalent(with: event) }
        return true
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let shelf, let notch else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let order = shelf.urls
        switch (event.keyCode, command) {
        case (49, false):
            guard !shelf.selection.isEmpty || ShelfQuickLook.shared.isVisible else { return false }
            ShelfQuickLook.shared.toggle(shelf.selectedURLs, notch: notch)
        case (51, _), (117, _):
            guard !shelf.selection.isEmpty else { return false }
            withAnimation(.smooth(duration: 0.25)) { shelf.removeSelected() }
        case (123, false):
            shelf.selection.move(by: -1, in: order)
        case (124, false):
            shelf.selection.move(by: 1, in: order)
        case (125, true):
            shelf.open(shelf.selectedURLs)
        default:
            guard command else { return false }
            switch key {
            case "a": shelf.selection.selectAll(order)
            case "c": shelf.copy(shelf.selectedURLs)
            case "v": withAnimation(.smooth(duration: 0.25)) { _ = shelf.paste() }
            case "o": shelf.open(shelf.selectedURLs)
            default: return false
            }
        }
        return true
    }

    // MARK: Quick Look

    // Quick Look calls these on the main thread, from an informal protocol that
    // doesn't say so.
    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { if let panel { ShelfQuickLook.shared.take(panel) } }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { if let panel { ShelfQuickLook.shared.release(panel) } }
    }

    // MARK: Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let shelf, let notch else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let menu = NSMenu()
        menu.delegate = self
        guard let url = file(at: point) else {
            menu.addItem(ShelfMenuItem.make(String(localized: "Adicionar arquivos…"), symbol: "plus") { [weak self] in self?.choose(shelf, notch) })
            if shelf.canPaste {
                menu.addItem(ShelfMenuItem.make(String(localized: "Colar"), symbol: "doc.on.clipboard") { withAnimation(.smooth(duration: 0.25)) { _ = shelf.paste() } })
            }
            if !shelf.items.isEmpty {
                menu.addItem(ShelfMenuItem.make(String(localized: "Selecionar tudo"), symbol: "checklist") { shelf.selection.selectAll(shelf.urls) })
                menu.addItem(.separator())
                menu.addItem(ShelfMenuItem.make(String(localized: "Esvaziar a Shelf"), symbol: "xmark.circle") { withAnimation(.smooth(duration: 0.25)) { shelf.clear() } })
            }
            return menu
        }
        if !shelf.selection.contains(url) {
            shelf.selection.click(url, mode: .replace, in: shelf.urls)
        }
        let urls = shelf.selectedURLs
        menu.addItem(ShelfMenuItem.make(String(localized: "Abrir"), symbol: "arrow.up.forward.app") { shelf.open(urls) })
        menu.addItem(ShelfMenuItem.make(String(localized: "Mostrar no Finder"), symbol: "folder") { shelf.reveal(urls) })
        menu.addItem(ShelfMenuItem.make(String(localized: "Quick Look"), symbol: "eye") { ShelfQuickLook.shared.show(urls, notch: notch) })
        menu.addItem(ShelfMenuItem.make(String(localized: "Copiar"), symbol: "doc.on.doc") { shelf.copy(urls) })
        menu.addItem(.separator())
        menu.addItem(ShelfMenuItem.make(String(localized: "AirDrop"), symbol: "dot.radiowaves.left.and.right") { shelf.airDrop(urls) })
        let picker = NSSharingServicePicker(items: urls)
        sharePicker = picker
        menu.addItem(picker.standardShareMenuItem)
        menu.addItem(.separator())
        let removeTitle = urls.count == 1 ? String(localized: "Tirar da Shelf") : String(localized: "Tirar \(urls.count) da Shelf")
        menu.addItem(ShelfMenuItem.make(removeTitle, symbol: "minus.circle") { withAnimation(.smooth(duration: 0.25)) { shelf.remove(urls) } })
        return menu
    }

    // The pointer wanders while a menu is up; the notch waits for it.
    private var heldBeforeMenu = false

    func menuWillOpen(_ menu: NSMenu) {
        guard let notch else { return }
        heldBeforeMenu = notch.holdsOpen
        notch.holdsOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        notch?.holdsOpen = heldBeforeMenu
    }
}

/// The source of a drag out of the tray. Its own object, kept alive until the session
/// ends, because the notch may close (and the tray's view go away) while the files are
/// still on their way to Finder.
private final class ShelfDragSource: NSObject, NSDraggingSource {
    private let shelf: ShelfModel
    private weak var notch: NotchState?
    private let urls: [URL]
    private var retainedSelf: ShelfDragSource?

    init(shelf: ShelfModel, notch: NotchState?, urls: [URL]) {
        self.shelf = shelf
        self.notch = notch
        self.urls = urls
        super.init()
        retainedSelf = self
        shelf.isDraggingOut = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Out of Cleen, let the destination decide (Finder moves on the same disk and
        // copies across disks, option copies); inside the panel there's nowhere to drop.
        context == .outsideApplication ? [.copy, .move, .link, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        shelf.isDraggingOut = false
        notch?.isDraggingFiles = false
        // Moved or thrown away: the path the shelf holds no longer leads anywhere.
        if operation.contains(.move) || operation.contains(.delete) {
            withAnimation(.smooth(duration: 0.25)) { shelf.remove(urls) }
        }
        shelf.prune()
        retainedSelf = nil
    }
}

/// A menu item that runs a closure, with an SF Symbol beside it. The closure's box is
/// the item's target, kept alive as its represented object.
private enum ShelfMenuItem {
    final class Action: NSObject {
        let handler: () -> Void

        init(_ handler: @escaping () -> Void) {
            self.handler = handler
        }

        @objc func run() {
            handler()
        }
    }

    static func make(_ title: String, symbol: String, handler: @escaping () -> Void) -> NSMenuItem {
        let action = Action(handler)
        let item = NSMenuItem(title: title, action: #selector(Action.run), keyEquivalent: "")
        item.target = action
        item.representedObject = action
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }
}
