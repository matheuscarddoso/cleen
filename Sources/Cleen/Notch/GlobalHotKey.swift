import Carbon.HIToolbox

/// A system-wide keyboard shortcut through Carbon's hot key API, which (unlike an
/// event tap) needs no Accessibility permission. Each shortcut gets its own id and
/// handles only its own presses, so several can live side by side.
final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    fileprivate let identifier: UInt32
    fileprivate let action: () -> Void
    /// False when another app already owns the combination.
    private(set) var isRegistered = false

    private static var nextIdentifier: UInt32 = 1

    /// ⌃⌥C: free in Finder and the common editors, and C for Cleen.
    static func standard(action: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey), action: action)
    }

    /// ⌥Space, where launchers live: opens the search.
    static func search(action: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), action: action)
    }

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            // Not ours: let the next shortcut's handler see it.
            guard pressed.id == hotKey.identifier else { return OSStatus(eventNotHandledErr) }
            // Carbon delivers hot keys on the main thread.
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &spec, context, &handler)

        let id = EventHotKeyID(signature: OSType(0x434C_4E4E), id: identifier) // "CLNN"
        isRegistered = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    isolated deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
