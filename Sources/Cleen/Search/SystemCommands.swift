import AppKit
import CleenKit
import os

/// The Mac-wide commands of the search: lock, sleep, restart, dark mode, hide or quit
/// every app, eject disks, empty the Lixo.
enum SystemCommands {
    nonisolated private static let log = Logger(subsystem: "app.cleen.Cleen", category: "system")

    /// The same as ⌃⌘Q.
    static func lockScreen() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyQ: CGKeyCode = 12
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyQ, keyDown: down)
            event?.flags = [.maskCommand, .maskControl]
            event?.post(tap: .cghidEventTap)
        }
    }

    static func sleep() {
        Task.detached { _ = try? await Shell.run("/usr/bin/pmset", ["sleepnow"]) }
    }

    static func screenSaver() {
        NSWorkspace.shared.openApplication(at: URL(filePath: "/System/Library/CoreServices/ScreenSaverEngine.app"), configuration: .init())
    }

    enum Power: String {
        case restart
        case shutDown = "shut down"
        case logOut = "log out"
    }

    /// Through System Events, as the Apple menu does: every app is asked to quit and can
    /// still stop it to save a document.
    static func power(_ action: Power) {
        script("tell application \"System Events\" to \(action.rawValue)")
    }

    static func toggleDarkMode() {
        script("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
    }

    /// The apps a "quit all" would close: everything with a Dock icon but Finder and Cleen.
    static var quittableApps: [NSRunningApplication] {
        let own = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != own && $0.bundleIdentifier != "com.apple.finder" && !$0.isTerminated
        }
    }

    /// Asks each app to quit, like ⌘Q: unsaved work still gets its own prompt.
    static func quitAll() {
        quittableApps.forEach { $0.terminate() }
    }

    /// Every app out of sight, the desktop in front.
    static func hideAll() {
        quittableApps.forEach { $0.hide() }
        // The keyboard goes to Finder (the desktop), not back to an app now hidden.
        PasteKeystroke.target = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
    }

    /// External drives, disk images and cards: what Finder shows an eject button for.
    static var ejectableVolumes: [URL] {
        let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        return (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []).filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            return values.volumeIsEjectable == true || values.volumeIsRemovable == true || values.volumeIsInternal == false
        }.filter { $0.path(percentEncoded: false) != "/" }
    }

    static func ejectAll(then report: @escaping @MainActor (Int, Int) -> Void) {
        let volumes = ejectableVolumes
        Task.detached {
            var failed = 0
            for volume in volumes {
                do { try NSWorkspace.shared.unmountAndEjectDevice(at: volume) } catch { failed += 1 }
            }
            await report(volumes.count - failed, failed)
        }
    }

    /// What's in the Lixo, for the review before emptying it. Reading it needs Full Disk
    /// Access; without it the list is empty and the review says just "Lixo".
    static var trashItems: [URL] {
        let trash = URL.homeDirectory.appending(path: ".Trash")
        return (try? FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [])) ?? []
    }

    /// Finder empties every volume's Lixo and deals with locked files itself.
    static func emptyTrash() {
        script("tell application \"Finder\" to empty trash")
    }

    private static func script(_ source: String) {
        Task.detached {
            guard let result = try? await Shell.run("/usr/bin/osascript", ["-e", source], timeout: .seconds(30)), result.succeeded else {
                log.error("system command failed: \(source, privacy: .public)")
                return
            }
        }
    }
}
