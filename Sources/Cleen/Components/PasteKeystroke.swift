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

    /// Sends ⌘V. Returns false, without sending, when Accessibility isn't granted; what
    /// was copied stays on the clipboard for a manual ⌘V.
    @discardableResult
    static func send() -> Bool {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        guard isAllowed else {
            log.error("paste skipped: no Accessibility permission (front: \(front, privacy: .public))")
            return false
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        let keyWindow = NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "none"
        log.info("paste sent to \(front, privacy: .public); Cleen active: \(NSApp.isActive), Cleen key window: \(keyWindow, privacy: .public)")
        return true
    }
}
