import AppKit
import SwiftUI

/// Puts the tour on screen, hanging from the notch: a dimmed backdrop that lets clicks
/// through, and the panel above it. While System Settings is in front (granting a
/// permission) the backdrop goes away and the panel steps down to a normal window, so
/// it never covers the switch the person is looking for.
final class OnboardingController {
    static let panelSize = CGSize(width: 880, height: 540)
    /// Room around the panel for its shadow.
    static let shadowPadding = 60.0

    let model = OnboardingModel()
    private let screen: NSScreen
    private var backdrop: OnboardingWindow?
    private var window: OnboardingWindow?
    private var observers: [NSObjectProtocol] = []
    private var keyMonitor: Any?

    init(screen: NSScreen) {
        self.screen = screen
    }

    func show(app: AppModel, onFinish: @escaping () -> Void) {
        GrainTexture.prepare()
        let geometry = NotchGeometry(screen: screen)
        let size = CGSize(
            width: min(Self.panelSize.width, screen.frame.width - 80),
            height: min(Self.panelSize.height, screen.visibleFrame.height - 60)
        )

        let backdrop = OnboardingWindow(frame: screen.frame, ignoresMouse: true)
        backdrop.level = .statusBar + 1
        backdrop.contentView = NSHostingView(rootView: OnboardingBackdrop().environment(model))
        backdrop.orderFrontRegardless()
        self.backdrop = backdrop

        let frame = CGRect(
            x: screen.frame.midX - size.width / 2 - Self.shadowPadding,
            y: screen.frame.maxY - size.height - Self.shadowPadding,
            width: size.width + Self.shadowPadding * 2,
            height: size.height + Self.shadowPadding
        )
        let window = OnboardingWindow(frame: frame, ignoresMouse: false)
        window.level = .statusBar + 2
        let root = OnboardingRootView(panelSize: size, notchSize: geometry.notchSize)
            .injecting(app)
            .environment(model)
        window.contentView = NSHostingView(rootView: root)
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()

        model.onFinish = { [weak self] in
            self?.close()
            onFinish()
        }
        observeActivation()
        installKeys()
        model.begin()
    }

    private func close() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        window?.orderOut(nil)
        backdrop?.orderOut(nil)
        window = nil
        backdrop = nil
    }

    private func observeActivation() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setForeground(false) }
        })
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setForeground(true) }
        })
    }

    private func setForeground(_ foreground: Bool) {
        guard model.phase != .leaving else { return }
        window?.level = foreground ? .statusBar + 2 : .normal
        if foreground {
            backdrop?.orderFrontRegardless()
            window?.makeKeyAndOrderFront(nil)
        } else {
            backdrop?.orderOut(nil)
        }
    }

    /// Return moves on, the arrows go back and forth, Esc skips the opening titles.
    private func installKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            if event.type == .flagsChanged {
                self.model.heldModifiers = event.modifierFlags.intersection([.control, .option])
                return event
            }
            switch event.keyCode {
            case 36, 76:
                if self.model.phase == .titles { self.model.skipTitles() } else { self.model.primary() }
            case 124: self.model.advance()
            case 123: self.model.back()
            case 53: if self.model.phase == .titles { self.model.skipTitles() }
            default: return event
            }
            return nil
        }
    }
}
