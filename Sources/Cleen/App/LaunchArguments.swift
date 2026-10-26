import Foundation

/// Launch flags for opening straight into a screen, used when checking the UI:
/// `--notch <tab>` opens the notch pinned on that tool, `--settings` opens Ajustes,
/// `--scan` starts that tool's scan right away, `--edit` opens Início in edit mode, `--live <kind>` previews a live activity,
/// `--onboarding` replays the first-run tour.
enum LaunchArguments {
    static let notchTab: NotchTab? = value(after: "--notch").flatMap(NotchTab.init(rawValue:))
    static let settings = ProcessInfo.processInfo.arguments.contains("--settings")
    /// `--settings notch` opens that page of Ajustes.
    static let settingsSection = value(after: "--settings").flatMap(SettingsSection.init(rawValue:))
    static let scan = ProcessInfo.processInfo.arguments.contains("--scan")
    static let editHome = ProcessInfo.processInfo.arguments.contains("--edit")
    /// `--welcome` shows the greeting the tour ends with.
    static let welcome = ProcessInfo.processInfo.arguments.contains("--welcome")
    /// `--search <text>` opens the launcher with that typed.
    static let search = value(after: "--search")
    /// `--prompt <text>`: the teleprompter reading that text (only into an empty script).
    static let prompt = value(after: "--prompt")
    /// `--live power|headphones|track|meeting` plays that live activity on the closed notch.
    static let liveActivity = value(after: "--live")
    static let onboarding = ProcessInfo.processInfo.arguments.contains("--onboarding")
    /// `--focus-check` opens the launcher and closes it two seconds later, for checking
    /// that the keyboard goes back to the app in front.
    static let focusCheck = ProcessInfo.processInfo.arguments.contains("--focus-check")
    /// `--paste-check <text>` does the same, pasting `text` on the way out (the clipboard
    /// is put back after), for checking the paste and where the keyboard ends up.
    static let pasteCheck = value(after: "--paste-check")
    /// `--editor <folder>` opens a recording in the editor; with `--export` it also
    /// exports it right away (for checking the renderer end to end).
    static let editor = value(after: "--editor").map { URL(filePath: $0, directoryHint: .isDirectory) }
    static let exportNow = ProcessInfo.processInfo.arguments.contains("--export")
    /// `--pick display|window|area` puts the recorder's floating bar up in that mode.
    static let pick = value(after: "--pick")

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
