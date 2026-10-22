import Foundation

/// Launch flags for opening straight into a screen, used when checking the UI:
/// `--open <route>` opens the main window on that section, `--panel-preview` shows the
/// menu bar panel in a window, `--scan` starts that section's scan right away.
enum LaunchArguments {
    static let route: Route? = value(after: "--open").flatMap(Route.init(rawValue:))
    static let panelPreview = ProcessInfo.processInfo.arguments.contains("--panel-preview")
    static let scan = ProcessInfo.processInfo.arguments.contains("--scan")

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
