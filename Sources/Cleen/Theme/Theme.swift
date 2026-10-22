import AppKit
import SwiftUI

/// The window's visual language: native macOS. System accent, system fonts, grouped
/// boxes like System Settings, and it follows light and dark mode. (The notch has its
/// own always-dark style in `NotchStyle`.)
enum Theme {
    // MARK: Color

    static let accent = Color.accentColor
    /// Text drawn on top of `accent`.
    static let onAccent = Color.white

    static let good = Color.green
    static let warning = Color.orange
    static let critical = Color.red

    static let canvas = Color(nsColor: .windowBackgroundColor)
    /// Grouped boxes: white on light, a lifted grey on dark — as in System Settings.
    static let surface = dynamic(light: .white, dark: NSColor.white.withAlphaComponent(0.055))
    static let surfaceHover = dynamic(
        light: NSColor.black.withAlphaComponent(0.045),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let hairline = Color(nsColor: .separatorColor)
    static let track = Color.primary.opacity(0.09)

    // MARK: Shape

    enum Radius {
        static let small = 6.0
        static let medium = 10.0
        static let large = 12.0
    }

    // MARK: Type

    /// Titles and hero numbers. SF only, semibold at most: hierarchy comes from size.
    static func display(_ size: Double) -> Font {
        .system(size: size, weight: .semibold)
    }

    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11)
    static let eyebrow = Font.system(size: 11, weight: .semibold)

    // MARK: Motion

    static let quick = Animation.smooth(duration: 0.18)
    static let standard = Animation.smooth(duration: 0.3)

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
