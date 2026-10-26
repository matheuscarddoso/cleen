import AppKit
import ApplicationServices
import os

/// Pastes into the app that's in front by sending it ⌘V; the notch never takes focus,
/// so that app is still the one you were typing in.
enum PasteKeystroke {
    static let log = Logger(subsystem: "app.cleen.Cleen", category: "paste")

    /// Sending keystrokes to other apps needs Accessibility.
    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Asks macOS for Accessibility (its own prompt the first time) and opens the list in
    /// Ajustes do Sistema, where the switch is.
    static func requestPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The app to paste into: the one in front when the notch took the keyboard. Kept
    /// because, for a moment after the notch closes, macOS may still route keys to Cleen.
    /// The app in front when the notch opened: where a pick is pasted and where the
    /// keyboard goes back.
    static var target: NSRunningApplication?

    static func rememberTarget() {
        guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        target = front
    }

    /// Gives activation back to the app you were in, the way Raycast does when it
    /// closes: macOS then brings back that app's own window and the field that had the
    /// cursor. Only while Cleen is still the active app; if you went to another app by
    /// clicking it, that's where you stay.
    static func handBack() {
        guard NSApp.isActive else { return }
        // Cleen's own window in front (the tour, Ajustes): that's where you are.
        guard !NSApp.windows.contains(where: { $0.isVisible && $0.isKeyWindow && !($0 is NotchPanel) }) else { return }
        if let app = target, !app.isTerminated {
            NSApp.yieldActivation(to: app)
            app.activate()
        } else {
            NSApp.deactivate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let system = AXUIElementCreateSystemWide()
            var focusedApp: CFTypeRef?
            AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &focusedApp)
            var pid: pid_t = 0
            if let focusedApp, CFGetTypeID(focusedApp) == AXUIElementGetTypeID() { AXUIElementGetPid(focusedApp as! AXUIElement, &pid) }
            let role = focusedElement(of: pid).flatMap { string($0, kAXRoleAttribute) } ?? "none"
            let name = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "none"
            log.info("keyboard now with \(name, privacy: .public), element \(role, privacy: .public); Cleen active: \(NSApp.isActive)")
        }
    }

    /// Waits (up to about half a second) for the app you were in to be in front again,
    /// so a paste goes in once its field has the cursor back.
    static func waitForTarget() async {
        guard let app = target, !app.isTerminated else { return }
        for _ in 0..<30 where NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
            try? await Task.sleep(for: .milliseconds(20))
        }
        // The window takes a beat more to hand its field the cursor.
        try? await Task.sleep(for: .milliseconds(40))
    }

    private static func focusedElement(of pid: pid_t) -> AXUIElement? {
        guard pid > 0 else { return nil }
        var element: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute as CFString, &element) == .success,
              let element, CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        return (element as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    /// Sends ⌘V straight to the target app's process, with ⌘ pressed and released around
    /// the V like a real keyboard, so it lands there whoever has the keyboard right now.
    /// Returns false, without sending, when Accessibility isn't granted; what was copied
    /// stays on the clipboard for a manual ⌘V.
    @discardableResult
    static func send() -> Bool {
        let app = target.flatMap { $0.isTerminated ? nil : $0 } ?? NSWorkspace.shared.frontmostApplication
        let name = app?.bundleIdentifier ?? "?"
        guard isAllowed else {
            log.error("paste skipped: no Accessibility permission (target: \(name, privacy: .public))")
            return false
        }
        let source = CGEventSource(stateID: .hidSystemState)
        // Command plus the left-⌘ device bit, as a physical key sets it: some apps
        // (Chromium ones among them) look at the device bits.
        let command = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x8)
        let keyCommand: CGKeyCode = 55
        let keyV: CGKeyCode = 9
        let events: [(CGKeyCode, Bool, CGEventFlags)] = [
            (keyCommand, true, command), (keyV, true, command), (keyV, false, command), (keyCommand, false, []),
        ]
        for (key, down, flags) in events {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = flags
            if let pid = app?.processIdentifier {
                event.postToPid(pid)
            } else {
                event.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
        log.info("paste sent to \(name, privacy: .public) (pid \(app?.processIdentifier ?? 0)); Cleen active: \(NSApp.isActive)")
        return true
    }
}
