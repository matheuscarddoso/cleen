import SwiftUI

/// The notch's own look: true black so it melts into the camera housing, neutral greys
/// for structure, color reserved for meaning (usage levels, warnings).
enum NotchStyle {
    static let background = Color.black
    /// The one surface: a barely lifted black with a hairline edge, never a gradient.
    static let card = Color.white.opacity(0.045)
    static let cardStroke = Color.white.opacity(0.07)
    static let separator = Color.white.opacity(0.07)
    /// Bar fill: light grey, not pure white, so bars sit back from the text.
    static let barFill = Color.white.opacity(0.78)
    static let control = Color.white.opacity(0.1)
    static let controlHover = Color.white.opacity(0.16)
    static let selection = Color.white.opacity(0.14)
    static let track = Color.white.opacity(0.12)

    static let primary = Color.white
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.32)

    static let good = Color(red: 0.36, green: 0.84, blue: 0.52)
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.24)
    static let critical = Color(red: 1.0, green: 0.33, blue: 0.33)

    static let cardRadius = 14.0
    static let openTopRadius = 14.0
    static let openBottomRadius = 30.0
    static let closedTopRadius = 6.0
    static let closedBottomRadius = 12.0

    static let title = Font.system(size: 15, weight: .semibold)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 12)
    static let bodyMedium = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 10.5)
    static let captionMedium = Font.system(size: 10.5, weight: .medium)

    /// Usage bars go white → orange → red as they fill, like a battery or a quota.
    static func level(_ fraction: Double) -> Color {
        switch fraction {
        case 0.9...: critical
        case 0.75...: warning
        default: barFill
        }
    }
}
