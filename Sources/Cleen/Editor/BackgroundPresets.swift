import CoreImage
import SwiftUI

/// The editor's gradients, two colors each, top-left to bottom-right.
nonisolated enum BackgroundPresets {
    static let gradients: [(String, String)] = [
        ("#4F7CFF", "#9B5CFF"),
        ("#0F2027", "#2C5364"),
        ("#FF7A59", "#FFB86B"),
        ("#11998E", "#38EF7D"),
        ("#EE0979", "#FF6A00"),
        ("#141E30", "#243B55"),
        ("#FBC2EB", "#A6C1EE"),
        ("#232526", "#414345"),
    ]

    static func colors(_ index: Int) -> (CIColor, CIColor) {
        let pair = gradients[max(0, min(gradients.count - 1, index))]
        return (CIColor(hex: pair.0), CIColor(hex: pair.1))
    }

    static func swatch(_ index: Int) -> LinearGradient {
        let pair = gradients[max(0, min(gradients.count - 1, index))]
        return LinearGradient(colors: [color(pair.0), color(pair.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// "#RRGGBB" as a SwiftUI color.
    static func color(_ hex: String) -> Color {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

nonisolated extension CIColor {
    /// "#RRGGBB"; anything else is black.
    convenience init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255)
    }
}
