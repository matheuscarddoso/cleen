import SwiftUI

/// Lustro's visual language: near-black canvas, one warm accent, hairlines instead of
/// shadows, serif display type for the numbers that matter.
enum Theme {
    // MARK: Color

    /// Champagne. The only chromatic color that isn't a status.
    static let accent = Color(red: 0.91, green: 0.79, blue: 0.56)
    /// Text drawn on top of `accent`.
    static let onAccent = Color(red: 0.13, green: 0.11, blue: 0.08)

    static let good = Color(red: 0.45, green: 0.84, blue: 0.66)
    static let warning = Color(red: 0.96, green: 0.73, blue: 0.40)
    static let critical = Color(red: 0.95, green: 0.47, blue: 0.42)

    static let canvas = Color(red: 0.047, green: 0.047, blue: 0.055)
    static let surface = Color.white.opacity(0.035)
    static let surfaceHover = Color.white.opacity(0.06)
    static let hairline = Color.white.opacity(0.08)
    static let track = Color.white.opacity(0.07)

    // MARK: Shape

    enum Radius {
        static let small = 7.0
        static let medium = 11.0
        static let large = 16.0
    }

    // MARK: Type

    /// Serif display for titles and hero numbers. Regular weight: hierarchy comes from size.
    static func display(_ size: Double) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11)
    static let eyebrow = Font.system(size: 10.5, weight: .medium)

    // MARK: Motion

    static let quick = Animation.smooth(duration: 0.18)
    static let standard = Animation.smooth(duration: 0.3)
}
