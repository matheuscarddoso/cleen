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

        let panel = NotchPanel(frame: geometry.windowFrame)
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
        pendingClose?.cancel()
        if let tab { state.tab = tab }
        guard !state.isOpen else { return }
        panel?.ignoresMouseEvents = false
        withAnimation(Self.openAnimation) { state.isOpen = true }
    }

    func close() {
        pendingOpen?.cancel()
        guard state.isOpen else { return }
        state.holdsOpen = false
        withAnimation(Self.closeAnimation) { state.isOpen = false }
        panel?.ignoresMouseEvents = true
    }

    func togglePin() {
        state.isPinned.toggle()
    }

    /// Opens a full-window section and tucks the notch away.
    func openWindow(_ route: Route) {
        app.route = route
        NotificationCenter.default.post(name: .cleenOpenMainWindow, object: nil)
        state.isPinned = false
        close()
    }

    // MARK: Pointer

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handlePointer(event)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask.union(.keyDown), handler: { [weak self] event in
            if event.type == .keyDown, event.keyCode == 53, self?.state.isOpen == true {
                self?.close()
                return nil
            }
            self?.handlePointer(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handlePointer(_ event: NSEvent) {
        guard let geometry = state.geometry else { return }
        let location = NSEvent.mouseLocation
        let wings = NotchSettings.showsWings

        if state.isOpen {
            let inside = geometry.hotZone(isOpen: true, showsWings: wings).contains(location)
            if inside {
                pendingClose?.cancel()
                pendingClose = nil
            } else if event.type == .leftMouseDown, !state.isPinned {
                // A click elsewhere is a clear "done".
                close()
            } else if pendingClose == nil, !state.isPinned, !state.holdsOpen {
                pendingClose = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(380))
                    guard !Task.isCancelled else { return }
                    self?.pendingClose = nil
                    self?.close()
                }
            }
            return
        }

        let overNotch = geometry.hotZone(isOpen: false, showsWings: wings).contains(location)
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
}

extension Notification.Name {
    /// Asks the SwiftUI scene layer to open the main window (it owns `openWindow`).
    static let cleenOpenMainWindow = Notification.Name("cleenOpenMainWindow")
}
