import AppKit
import SwiftUI

/// One notch panel on one screen: opens when the pointer comes to the notch, closes
/// when it leaves. `NotchCoordinator` decides which screens get one.
final class NotchController {
    let state = NotchState()
    let screen: NSScreen
    private unowned let app: AppModel
    private var panel: NotchPanel?
    private var monitors: [Any] = []
    private var pendingOpen: Task<Void, Never>?
    private var pendingClose: Task<Void, Never>?
    /// While set, a panel opened by Cleen itself doesn't close on the next mouse move.
    private var presentedUntil: Date?
    /// The drag pasteboard's change count when the mouse went down, to tell a file drag
    /// (it changes) from dragging a window or selecting text across the menu bar.
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    /// The trackpad swipe in progress over the notch, summed until it's decisive.
    private var swipe = CGVector.zero
    private var swipeHandled = false

    /// Springy like the system's own island: quick to arrive, settles without wobble.
    static let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8)
    static let closeAnimation = Animation.spring(response: 0.34, dampingFraction: 0.92)

    init(app: AppModel, screen: NSScreen) {
        self.app = app
        self.screen = screen
    }

    func install() {
        guard panel == nil else { return }
        let geometry = NotchGeometry(screen: screen)
        state.geometry = geometry

        let panel = NotchPanel(frame: geometry.windowFrame(showsSearch: false))
        panel.acceptsKeyboard = { [weak self] in self?.state.isOpen == true }
        let root = NotchRootView(controller: self)
            .injecting(app)
            .environment(state)
        panel.contentView = NSHostingView(rootView: root)
        panel.orderFrontRegardless()
        self.panel = panel

        installMonitors()
    }

    func uninstall() {
        pendingOpen?.cancel()
        pendingClose?.cancel()
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: Open and close

    func toggle() {
        state.isOpen ? close() : open()
    }

    func open(tab: NotchTab? = nil) {
        // Picks in Emoji, Clipboard and the others paste into the app in front now.
        if !state.isOpen { PasteKeystroke.rememberTarget() }
        pendingClose?.cancel()
        if let tab {
            state.tab = tab
            state.showsSettings = false
        }
        guard !state.isOpen else { return }
        panel?.ignoresMouseEvents = false
        withAnimation(Self.openAnimation) { state.isOpen = true }
    }

    func close() {
        pendingOpen?.cancel()
        guard state.isOpen else { return }
        state.pasteNeedsPermission = false
        state.holdsOpen = false
        state.mirrorExpanded = false
        state.isEditingHome = false
        if state.opensInstantly {
            withTransaction(Self.instant) { state.isOpen = false }
        } else {
            withAnimation(Self.closeAnimation) { state.isOpen = false }
        }
        state.showsSearch = false
        state.showsWelcome = false
        state.opensInstantly = false
        panel?.ignoresMouseEvents = true
        giveBackKeyboard()
    }

    // MARK: Welcome

    /// After the tour: the "hello" island, which stays until one of its buttons.
    func presentWelcome() {
        pendingClose?.cancel()
        state.showsSettings = false
        state.showsSearch = false
        state.showsWelcome = true
        state.holdsOpen = true
        panel?.ignoresMouseEvents = false
        withAnimation(Self.openAnimation) { state.isOpen = true }
    }

    /// Grows the island into the panel on Início (in edit mode for "Personalizar").
    func dismissWelcome(editing: Bool) {
        withAnimation(Self.openAnimation) {
            state.tab = .home
            state.showsWelcome = false
            state.holdsOpen = false
            if editing { state.isEditingHome = true }
        }
    }

    // MARK: Search

    private static var instant: Transaction {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return transaction
    }

    /// ⌥Space: the launcher, there at once and with the keyboard in its field. Opened
    /// on the panel already showing, it just switches to the search.
    func openSearch() {
        pendingClose?.cancel()
        PasteKeystroke.rememberTarget()
        app.search.prepare()
        state.showsSettings = false
        state.mirrorExpanded = false
        let wasOpen = state.isOpen
        fitWindow(showsSearch: true)
        if wasOpen {
            // From an open panel the launcher grows out of it.
            withAnimation(Self.searchResize) { state.showsSearch = true }
        } else {
            state.opensInstantly = true
            withTransaction(Self.instant) { state.showsSearch = true }
        }
        // Moving the pointer away doesn't close a launcher; Esc or a click elsewhere does.
        state.holdsOpen = true
        panel?.ignoresMouseEvents = false
        if !wasOpen { withTransaction(Self.instant) { state.isOpen = true } }
        // A non-activating panel can take the keyboard without the app in front changing,
        // so window commands and pastes still go to the app you were in.
        panel?.makeKey()
        // The field asks for the cursor only once the window really is key: on the next
        // turn of the run loop, after AppKit has finished making it so.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.state.showsSearch else { return }
            if self.panel?.isKeyWindow == false { self.panel?.makeKey() }
            self.state.searchFocusRequest += 1
        }
    }

    /// How the panel grows into the launcher and back.
    static let searchResize = Animation.spring(response: 0.4, dampingFraction: 0.86)

    private var pendingShrink: Task<Void, Never>?

    /// Sizes the window for the launcher at once when it opens; when it goes, waits for
    /// the panel to finish shrinking before taking the room back.
    func fitWindow(showsSearch: Bool) {
        pendingShrink?.cancel()
        guard let geometry = state.geometry, let panel else { return }
        let frame = geometry.windowFrame(showsSearch: showsSearch)
        if showsSearch {
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            return
        }
        pendingShrink = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self, !self.state.showsSearch, let panel = self.panel else { return }
            if panel.frame != frame { panel.setFrame(frame, display: true) }
        }
    }

    func toggleSearch() {
        state.isOpen && state.showsSearch ? close() : openSearch()
    }

    /// Closes the launcher; with `paste`, sends ⌘V to the app you were in once it has
    /// the keyboard back.
    func closeSearch(paste: Bool) {
        // Without Accessibility the paste can't happen: stay open and say how to allow it,
        // instead of closing on something that silently didn't paste.
        if paste, !PasteKeystroke.isAllowed {
            PasteKeystroke.log.error("paste blocked: asking for Accessibility")
            state.pasteNeedsPermission = true
            return
        }
        close()
        guard paste else { return }
        // With one of Cleen's own windows in front (Ajustes, the tour), step back so the
        // app underneath is the one that gets the paste.
        if NSApp.isActive { NSApp.deactivate() }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            PasteKeystroke.send()
        }
    }

    /// The panel had the keyboard (search, a text field): hand it back to the app in
    /// front, which never stopped being active.
    /// Hands the keyboard back to the app you were in, so a paste lands there.
    /// `resignKey()` only reports a change, it doesn't make one: the panel stayed key and
    /// a ⌘V sent after closing went to Cleen. Ordering the panel out is what really gives
    /// up key status (no closed panel can take it over, see `NotchPanel.acceptsKeyboard`);
    /// ordering it straight back in keeps the closed notch on screen, so nothing flickers.
    /// Then the app you were in gets the keyboard back.
    private func giveBackKeyboard() {
        guard let panel, panel.isKeyWindow else { return }
        panel.orderOut(nil)
        panel.orderFrontRegardless()
        PasteKeystroke.restoreFocus()
    }

    func togglePin() {
        state.isPinned.toggle()
    }

    func present(tab: NotchTab) {
        presentedUntil = .now.addingTimeInterval(8)
        open(tab: tab)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8.2))
            guard let self, let until = self.presentedUntil, until <= .now else { return }
            self.presentedUntil = nil
            if !self.state.isPinned, !self.state.holdsOpen, !self.pointerIsInside { self.close() }
        }
    }

    /// A request that needs an answer (Claude Code asking for permission): opens on the
    /// tab and stays until the person comes to it or it's settled. It doesn't take the
    /// keyboard on arrival — you may be typing in the terminal right then; it takes it
    /// once the pointer comes to the panel, so Return and Esc reach the card. The
    /// launcher and the welcome aren't interrupted; the wing shows the request instead.
    func presentRequest(tab: NotchTab) {
        guard !state.showsSearch, !state.showsWelcome else { return }
        presentedUntil = .distantFuture
        open(tab: tab)
    }

    /// The request was settled (here, in the terminal, or it ran out of time): a panel
    /// that opened only for it goes back up; one the person came to stays.
    func endRequest() {
        guard presentedUntil == .distantFuture else { return }
        presentedUntil = nil
        if !state.isPinned, !state.holdsOpen, !pointerIsInside { close() }
    }

    /// A text field or the note has the cursor: the panel stays while the pointer is
    /// moved out of the way to type, until Esc or a click elsewhere.
    private var isTyping: Bool {
        guard let panel, panel.isKeyWindow else { return false }
        return panel.firstResponder is NSText
    }

    private var pointerIsInside: Bool {
        state.geometry?.hotZone(isOpen: true, showsWings: NotchSettings.showsWings, showsSearch: state.isTall).contains(NSEvent.mouseLocation) ?? false
    }

    /// Opens the panel on Ajustes.
    func openSettings(_ section: SettingsSection? = nil) {
        if let section { state.settingsSection = section }
        state.showsSettings = true
        open()
    }

    // MARK: Pointer

    private var isDraggingFiles: Bool {
        let pasteboard = NSPasteboard(name: .drag)
        return pasteboard.changeCount != dragChangeCount
            && pasteboard.types?.contains(.fileURL) == true
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handlePointer(event)
        }) {
            monitors.append(global)
        }
        // Two-finger swipes reach Cleen over other apps too, without any permission.
        for install in [NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            self?.handleSwipe(event)
        }) as Any?, NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            self?.handleSwipe(event)
            return event
        }) as Any?] {
            if let install { monitors.append(install) }
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask.union(.keyDown), handler: { [weak self] event in
            // Only Esc typed in the notch itself: Quick Look and the file picker close with theirs.
            if event.type == .keyDown, event.keyCode == 53, let self, self.state.isOpen, event.window === self.panel {
                if self.state.escapeHandler?() != true { self.close() }
                return nil
            }
            self?.handlePointer(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handlePointer(_ event: NSEvent) {
        guard let geometry = state.geometry, !app.notch.isSuspended else { return }
        let location = NSEvent.mouseLocation
        let wings = NotchSettings.showsWings

        if event.type == .leftMouseDown {
            dragChangeCount = NSPasteboard(name: .drag).changeCount
        }

        if state.isOpen {
            let inside = geometry.hotZone(isOpen: true, showsWings: wings, showsSearch: state.isTall).contains(location)
            // Only the shelf takes files, so only it pays for reading the drag pasteboard.
            let draggingFiles = inside && event.type == .leftMouseDragged && state.tab == .shelf && !state.showsSettings && isDraggingFiles
            if state.isDraggingFiles != draggingFiles { state.isDraggingFiles = draggingFiles }
            if inside {
                pendingClose?.cancel()
                pendingClose = nil
                // The person came to a request: now Return and Esc should answer it.
                if presentedUntil == .distantFuture, panel?.isKeyWindow == false { panel?.makeKey() }
                // Once the person comes to it, it behaves like any other open panel.
                presentedUntil = nil
            } else if let until = presentedUntil, until > .now {
                return
            } else if event.type == .leftMouseDown, !state.isPinned, !state.showsWelcome, !(state.holdsOpen && event.window != nil) {
                // A click elsewhere is a clear "done", except in the Cleen window that's
                // holding the panel open (the file picker, Quick Look).
                close()
            } else if pendingClose == nil, !state.isPinned, !state.holdsOpen, !isTyping {
                pendingClose = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(380))
                    guard !Task.isCancelled, let self else { return }
                    self.pendingClose = nil
                    if !self.isTyping { self.close() }
                }
            }
            return
        }

        let overNotch = geometry.hotZone(isOpen: false, showsWings: wings).contains(location)
        if overNotch, event.type == .leftMouseDragged, isDraggingFiles {
            state.isDraggingFiles = true
            open(tab: .shelf)
            return
        }
        guard overNotch else {
            pendingOpen?.cancel()
            pendingOpen = nil
            return
        }
        if event.type == .leftMouseDown {
            open()
        } else if NotchSettings.opensOnHover, pendingOpen == nil {
            let delay = NotchSettings.hoverDelay
            pendingOpen = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.pendingOpen = nil
                self?.open()
            }
        }
    }

    // MARK: Gestures

    /// Points of travel that make a swipe count.
    private static let swipeThreshold = 28.0

    /// Over the closed notch: two fingers down open it, sideways skip the track that's
    /// playing. Over the open panel, two fingers up close it (only when the scroll isn't
    /// a list's: a swipe that starts inside scrollable content just scrolls).
    private func handleSwipe(_ event: NSEvent) {
        guard NotchSettings.allowsGestures, let geometry = state.geometry, !app.notch.isSuspended,
              event.hasPreciseScrollingDeltas
        else { return }
        if event.phase == .began {
            swipe = .zero
            swipeHandled = false
        }
        defer {
            if event.phase == .ended || event.phase == .cancelled {
                swipe = .zero
                swipeHandled = false
            }
        }
        guard event.momentumPhase.isEmpty, !swipeHandled else { return }
        let location = NSEvent.mouseLocation
        let wings = NotchSettings.showsWings
        // Content moves with the fingers under natural scrolling; undo that so "down"
        // always means the fingers moved down.
        let flip = event.isDirectionInvertedFromDevice ? 1.0 : -1.0
        swipe.dx += event.scrollingDeltaX * flip
        swipe.dy += event.scrollingDeltaY * flip

        if !state.isOpen {
            guard geometry.hotZone(isOpen: false, showsWings: wings).insetBy(dx: -10, dy: -6).contains(location) else { return }
            if swipe.dy < -Self.swipeThreshold, abs(swipe.dy) > abs(swipe.dx) {
                swipeHandled = true
                open()
            } else if abs(swipe.dx) > Self.swipeThreshold * 1.4, abs(swipe.dx) > abs(swipe.dy) * 1.5, app.nowPlaying.track != nil {
                swipeHandled = true
                let command: NowPlayingCommand = swipe.dx > 0 ? .next : .previous
                Task { await app.nowPlaying.send(command) }
            }
        } else if swipe.dy > Self.swipeThreshold * 1.6, abs(swipe.dy) > abs(swipe.dx) * 1.5 {
            // Only from the strip by the camera, where nothing scrolls.
            let strip = CGRect(x: geometry.screenFrame.midX - geometry.openSize.width / 2, y: geometry.screenFrame.maxY - geometry.notchSize.height - 8,
                               width: geometry.openSize.width, height: geometry.notchSize.height + 8)
            guard strip.contains(location), !state.holdsOpen else { return }
            swipeHandled = true
            state.isPinned = false
            close()
        }
    }
}
