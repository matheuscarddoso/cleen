import SwiftUI

/// The editor's look, measured off Screen Studio's: near-black window, a raised
/// inspector, violet for what's active, amber clips and violet zooms on the timeline.
enum EditorTheme {
    static let window = Color(hex: 0x06080D)
    static let panel = Color(hex: 0x181B22)
    static let rail = Color(hex: 0x1F242A)
    static let control = Color(hex: 0x1F2228)
    static let controlSelected = Color(hex: 0x2F333A)
    static let controlStroke = Color(hex: 0x3E4050)
    static let separator = Color(hex: 0x232832)

    static let primary = Color.white
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color(hex: 0x6A6A6C)

    static let accent = Color(hex: 0x5141F7)
    static let accentSoft = Color(hex: 0xB1A5FB)
    static let playhead = Color(hex: 0x5F4EF7)
    static let hoverPin = Color(hex: 0x343A49)

    static let clipTop = Color(hex: 0xA6740C)
    static let clipBottom = Color(hex: 0xD29410)
    static let clipDim = Color(hex: 0x4F3C1E)
    static let clipStroke = Color(hex: 0xF2CD86)
    static let zoomTop = Color(hex: 0x5C4BF2)
    static let zoomBottom = Color(hex: 0x8D7EFA)

    static let body = Font.system(size: 13, weight: .regular)
    static let label = Font.system(size: 13, weight: .medium)
    static let title = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 11.5, weight: .regular)
}

/// Export: the one violet button.
struct EditorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(EditorTheme.accent.opacity(configuration.isPressed ? 0.85 : 1), in: .rect(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A quiet full-width button in the inspector (Remove slice, Pick random wallpaper).
struct EditorSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EditorTheme.label)
            .foregroundStyle(EditorTheme.primary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(configuration.isPressed ? EditorTheme.controlSelected : EditorTheme.control, in: .rect(cornerRadius: 9, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.05)) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// An icon in the title bar, the rails and the transport: white, dimmed when off, with a
/// soft backdrop under the pointer.
struct EditorIconButtonStyle: ButtonStyle {
    var size: CGFloat = 34
    var isOn = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(isOn ? EditorTheme.accentSoft : (isEnabled ? EditorTheme.primary : EditorTheme.tertiary.opacity(0.6)))
            .frame(width: size, height: size)
            .background(isHovered && isEnabled ? Color.white.opacity(0.07) : .clear, in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
