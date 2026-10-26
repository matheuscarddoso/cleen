import CleenKit
import Foundation

/// Hides the Dock while recording (System Events' "autohide") and puts it back after.
/// What it was is written down first, so a crash mid-recording is undone on the next
/// launch instead of leaving the Dock changed.
enum DockHider {
    private static let changedKey = "recorder.dockAutohideChanged"

    static func hide() async {
        guard await autohide() == false else { return }
        UserDefaults.standard.set(true, forKey: changedKey)
        await set(true)
    }

    static func restore() async {
        guard UserDefaults.standard.bool(forKey: changedKey) else { return }
        UserDefaults.standard.removeObject(forKey: changedKey)
        await set(false)
    }

    private static func autohide() async -> Bool? {
        guard let result = try? await Shell.run("/usr/bin/osascript", ["-e", "tell application \"System Events\" to get autohide of dock preferences"], timeout: .seconds(5)),
              result.succeeded else { return nil }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private static func set(_ on: Bool) async {
        _ = try? await Shell.run("/usr/bin/osascript", ["-e", "tell application \"System Events\" to set autohide of dock preferences to \(on)"], timeout: .seconds(5))
    }
}
