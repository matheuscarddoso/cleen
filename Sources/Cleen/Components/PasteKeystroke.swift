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
    static var target: NSRunningApplication?

    /// Gives the keyboard back to the target app and its window. The panel had it, and
    /// macOS doesn't hand it back to an app that was already in front when the panel
    /// goes; Accessibility can: the app is made frontmost again and its focused window
    /// main, which moves the keyboard there.
    static func restoreFocus() {
        guard isAllowed, let app = target, !app.isTerminated else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        var window: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success, let window {
            // A CFTypeRef from kAXFocusedWindowAttribute is always an AXUIElement.
            let focused = window as! AXUIElement
            AXUIElementSetAttributeValue(focused, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(focused, kAXRaiseAction as CFString)
        }
        log.info("focus restored to \(app.bundleIdentifier ?? "?", privacy: .public)")
    }

    /// Remembers the app in front, unless it's Cleen itself.
    static func rememberTarget() {
        guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        target = front
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
