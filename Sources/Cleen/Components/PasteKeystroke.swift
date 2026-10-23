import ApplicationServices

/// Pastes into the app that's in front by sending it ⌘V; the notch never takes focus,
/// so that app is still the one you were typing in.
enum PasteKeystroke {
    /// Needs Accessibility permission: without it, asks for it once and returns false,
    /// leaving whatever is on the clipboard for a manual ⌘V.
    @discardableResult
    static func send() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        guard trusted else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return true
    }
}
