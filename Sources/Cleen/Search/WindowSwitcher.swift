import AppKit
import ApplicationServices

/// Every window open on this Space, found through Accessibility, for "trocar de
/// janela": type part of a title ("Gmail", "cleen") and jump straight to it.
struct OpenWindow: Identifiable, Sendable {
    let id: String
    let title: String
    let appName: String
    let appURL: URL?
    let pid: pid_t
    let isMinimized: Bool
    /// The window's place in its app's list, to find it again when raising it.
    let index: Int
}

enum WindowSwitcher {
    /// Blocking: a slow app can take its timeout to answer. Call it off the main thread.
    nonisolated static func list() -> [OpenWindow] {
        guard AXIsProcessTrusted() else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated }
        var windows: [OpenWindow] = []
        for app in apps {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            // A hung app must not hold up the whole list.
            AXUIElementSetMessagingTimeout(element, 0.15)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success, let list = value as? [AXUIElement] else { continue }
            for (index, window) in list.enumerated() {
                guard string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole as String else { continue }
                let title = string(window, kAXTitleAttribute) ?? ""
                let name = app.localizedName ?? ""
                windows.append(OpenWindow(
                    id: "\(app.processIdentifier).\(index).\(title)",
                    title: title.isEmpty ? name : title,
                    appName: name,
                    appURL: app.bundleURL,
                    pid: app.processIdentifier,
                    isMinimized: bool(window, kAXMinimizedAttribute),
                    index: index
                ))
            }
        }
        return windows
    }

    /// Brings the window forward (un-minimizing it) and makes its app the one that gets
    /// the keyboard once the search closes.
    @discardableResult
    static func focus(_ window: OpenWindow) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return false }
        let element = AXUIElementCreateApplication(window.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement], let target = match(window, in: list) else { return false }
        if window.isMinimized { AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
        AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        // Closing the search hands activation to this app instead of the one before.
        PasteKeystroke.target = app
        return true
    }

    /// Closes the window with its own close button, so the app can still ask to save.
    static func close(_ window: OpenWindow) {
        let element = AXUIElementCreateApplication(window.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement], let target = match(window, in: list) else { return }
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target, kAXCloseButtonAttribute as CFString, &button) == .success, let button else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    /// The same title wins; the same place in the list is the fallback for windows
    /// whose title changed since the list was made.
    private static func match(_ window: OpenWindow, in list: [AXUIElement]) -> AXUIElement? {
        list.first { string($0, kAXTitleAttribute) == window.title } ?? (list.indices.contains(window.index) ? list[window.index] : nil)
    }

    nonisolated private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    nonisolated private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }
}
