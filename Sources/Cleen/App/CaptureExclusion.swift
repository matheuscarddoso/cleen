import AppKit

/// Keeps Cleen out of every screenshot, recording and screen share: the system's
/// (⌘⇧3/4/5), Cleen's own recorder and any other app's (meetings, QuickTime, OBS).
///
/// A window whose `sharingType` is `.none` is left out by the window server itself, so
/// no capture API sees it, whoever is capturing. Cleen marks the windows it makes as
/// they're made, so not one frame of them is captured; the ones AppKit makes for it (the
/// menu bar item, Quick Look, the file picker, alerts) are marked the moment they come
/// on screen.
enum CaptureExclusion {
    /// `--capturable` lets captures see Cleen again, for the UI screenshots in `scripts/`.
    static let isEnabled = !LaunchArguments.capturable

    /// Windows that must be captured (see `allow`), held weakly.
    private static let allowed = NSHashTable<NSWindow>.weakObjects()
    private static var observer: NSObjectProtocol?

    /// Marks the windows already up and every one that comes on screen from now on.
    static func start() {
        guard isEnabled, observer == nil else { return }
        NSApp.windows.forEach(apply)
        // Posted for each window as it goes on screen (and off, and covered): the first
        // moment a window AppKit made can be told apart from one that isn't shown.
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { note in
            let id = ObjectIdentifier(note.object as AnyObject)
            MainActor.assumeIsolated {
                if let window = NSApp.windows.first(where: { ObjectIdentifier($0) == id }) { apply(window) }
            }
        }
    }

    /// For a window Cleen makes: called before it's ordered in.
    static func exclude(_ window: NSWindow) {
        apply(window)
    }

    /// A window that has to be in captures: the wallpaper laid over the desktop icons
    /// while Cleen records, which is only there for the recording to show it.
    static func allow(_ window: NSWindow) {
        allowed.add(window)
        window.sharingType = .readOnly
    }

    private static func apply(_ window: NSWindow) {
        guard isEnabled, window.sharingType != .none, !allowed.contains(window) else { return }
        window.sharingType = .none
    }
}
