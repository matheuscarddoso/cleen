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
        ("#3A1C71", "#D76D77"),
        ("#00C6FF", "#0072FF"),
        ("#F7971E", "#FFD200"),
        ("#8E2DE2", "#4A00E0"),
        ("#1D976C", "#93F9B9"),
        ("#FC466B", "#3F5EFB"),
        ("#0B0B12", "#2B2D42"),
        ("#E0EAFC", "#CFDEF3"),
    ]

    /// Flat colors for the Color page.
    static let solids = [
        "#000000", "#111318", "#1F2937", "#374151", "#9CA3AF", "#E5E7EB", "#FFFFFF", "#F5F0E8",
        "#5141F7", "#2563EB", "#0EA5E9", "#10B981", "#84CC16", "#F59E0B", "#F97316", "#EF4444",
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
