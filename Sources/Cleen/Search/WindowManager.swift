import AppKit
import ApplicationServices
import CleenKit

/// Moves and resizes the window of the app you were in through Accessibility,
/// Rectangle/Raycast style.
enum WindowManager {
    /// Each window's frame before Cleen first moved it, for "Restaurar".
    private static var originals: [Int: CGRect] = [:]

    /// Asks for Accessibility the first time (macOS shows its own prompt).
    static var isTrusted: Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    @discardableResult
    static func apply(_ layout: WindowLayout) -> Bool {
        guard isTrusted, let window = focusedWindow(), let frame = frame(of: window), let screen = screen(containing: frame) else { return false }
        remember(window, frame)
        return setFrame(layout.frame(in: usableArea(of: screen), current: frame), of: window)
    }

    /// Sends the window to the next display, keeping its place and proportion there.
    @discardableResult
    static func moveToNextScreen() -> Bool {
        guard isTrusted, NSScreen.screens.count > 1, let window = focusedWindow(), let frame = frame(of: window),
              let screen = screen(containing: frame), let index = NSScreen.screens.firstIndex(of: screen)
        else { return false }
        let next = NSScreen.screens[(index + 1) % NSScreen.screens.count]
        remember(window, frame)
        return setFrame(WindowLayout.moved(frame, from: usableArea(of: screen), to: usableArea(of: next)), of: window)
    }

    @discardableResult
    static func restore() -> Bool {
        guard isTrusted, let window = focusedWindow(), let original = originals[Int(CFHash(window))] else { return false }
        originals[Int(CFHash(window))] = nil
        return setFrame(original, of: window)
    }

    // MARK: Accessibility

    /// The app you were in: while the search is open Cleen is the active app (it has
    /// the keyboard), so that's the one remembered when it opened.
    private static var targetApp: NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() { return front }
        return PasteKeystroke.target.flatMap { $0.isTerminated ? nil : $0 }
    }

    private static func focusedWindow() -> AXUIElement? {
        guard let app = targetApp else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success, let window else { return nil }
        return (window as! AXUIElement)
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    /// Size, position, then size again: apps that clamp their size to the screen they're
    /// on only accept the final size once they've moved.
    private static func setFrame(_ frame: CGRect, of window: AXUIElement) -> Bool {
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let dimensions = AXValueCreate(.cgSize, &size) else { return false }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        return moved == .success
    }

    private static func remember(_ window: AXUIElement, _ frame: CGRect) {
        let key = Int(CFHash(window))
        if originals[key] == nil { originals[key] = frame }
    }

    // MARK: Screens (Accessibility's top-left coordinates)

    private static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// The screen under most of the window.
    private static func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            area(frame.intersection(topLeft(lhs.frame))) < area(frame.intersection(topLeft(rhs.frame)))
        }
    }

    private static func usableArea(of screen: NSScreen) -> CGRect {
        topLeft(screen.visibleFrame)
    }

    private static func topLeft(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
