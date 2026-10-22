import SwiftUI

/// A white glyph on a colored rounded square, the way System Settings and Apple's own
/// apps label their tools.
struct ToolIcon: View {
    let symbol: String
    let color: Color
    var size = 22.0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color.mix(with: .white, by: 0.18), color], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: size * 0.26, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}
