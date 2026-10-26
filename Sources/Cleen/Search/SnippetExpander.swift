import AppKit
import ApplicationServices
import CleenKit
import os

/// Types a snippet out where its keyword was typed: `;email` becomes the address, in any
/// app. Watches keystrokes through an event tap (it needs Accessibility, which pasting
/// already asks for); password fields use secure input, which hides them from any tap.
///
/// Only the last few dozen characters are kept, in memory, and they're dropped whenever
/// the cursor could have moved (a click, an arrow, Return, a ⌘ shortcut).
final class SnippetExpander {
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "snippets")
    /// Stamped on the keys Cleen sends, so the tap doesn't read its own typing.
    nonisolated private static let marker: Int64 = 0x434C_4E4E

    private unowned let library: SearchLibrary
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var buffer = TypedBuffer()
    private var isExpanding = false

    init(library: SearchLibrary) {
        self.library = library
    }

    /// Runs only while it has something to do: the setting is on, a snippet has a
    /// keyword, and Accessibility is allowed.
    func update() {
        let wanted = library.expandsSnippets && library.snippets.contains { $0.keyword.count >= 2 } && AXIsProcessTrusted()
        if wanted, tap == nil { start() } else if !wanted, tap != nil { stop() }
    }

    private func start() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let expander = Unmanaged<SnippetExpander>.fromOpaque(context).takeUnretainedValue()
            // The tap is on the main run loop.
            MainActor.assumeIsolated { expander.handle(type, event) }
            return Unmanaged.passUnretained(event)
        }, userInfo: context) else {
            Self.log.error("snippet tap refused")
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
    }

    private func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        buffer.reset()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        case .keyDown:
            break
        default:
            buffer.reset()
            return
        }
        guard !isExpanding, event.getIntegerValueField(.eventSourceUserData) != Self.marker else { return }
        // Typing in Cleen itself (the search, a snippet's own editor) never expands.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            buffer.reset()
            return
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch keyCode {
        case 51: buffer.backspace() // ⌫
        case 36, 48, 53, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126: buffer.reset() // ↩ ⇥ ⎋ ⌤, page and arrow keys
        default:
            var length = 0
            var characters = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &characters)
            guard length > 0 else { return }
            buffer.append(String(utf16CodeUnits: characters, count: length))
            if let snippet = Snippet.justTyped(buffer.text, in: library.snippets) {
                buffer.reset()
                // After this keystroke has reached the app, so the keyword is all there.
                DispatchQueue.main.async { [weak self] in self?.expand(snippet) }
            }
        }
    }

    /// Erases the keyword, pastes the text, puts the cursor where `{cursor}` was, and
    /// gives the clipboard back as it was.
    private func expand(_ snippet: Snippet) {
        isExpanding = true
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        } ?? []
        let (text, back) = snippet.expanded(clipboard: pasteboard.string(forType: .string))

        let source = CGEventSource(stateID: .hidSystemState)
        func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
                event.flags = flags
                event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
                event.post(tap: .cgSessionEventTap)
            }
        }
        for _ in 0..<snippet.keyword.count { key(51) }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Clipboard managers (Cleen's own history too) skip transient copies.
        pasteboard.setData(Data(), forType: .init("org.nspasteboard.TransientType"))
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            key(9, flags: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x8)) // ⌘V
            try? await Task.sleep(for: .milliseconds(40))
            for _ in 0..<back { key(123) } // ←
            try? await Task.sleep(for: .milliseconds(400))
            pasteboard.clearContents()
            for item in saved where !item.isEmpty {
                let restored = NSPasteboardItem()
                for (type, data) in item { restored.setData(data, forType: type) }
                // Already in every clipboard history: putting it back isn't a new copy.
                restored.setData(Data(), forType: .init("org.nspasteboard.TransientType"))
                pasteboard.writeObjects([restored])
            }
            isExpanding = false
        }
    }
}
