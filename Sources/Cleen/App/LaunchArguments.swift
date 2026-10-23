import Foundation

/// Launch flags for opening straight into a screen, used when checking the UI:
/// `--notch <tab>` opens the notch pinned on that tool, `--settings` opens Ajustes,
/// `--scan` starts that tool's scan right away, `--onboarding` replays the first-run tour.
enum LaunchArguments {
    static let notchTab: NotchTab? = value(after: "--notch").flatMap(NotchTab.init(rawValue:))
    static let settings = ProcessInfo.processInfo.arguments.contains("--settings")
    static let scan = ProcessInfo.processInfo.arguments.contains("--scan")
    static let onboarding = ProcessInfo.processInfo.arguments.contains("--onboarding")

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
