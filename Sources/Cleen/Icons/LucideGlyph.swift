import CleenKit
import SwiftUI

/// One Lucide icon, drawn as a character of the Lucide font: no per-icon image to load.
/// The font draws Lucide's 24-unit grid across `size`, so the icon keeps its own margins
/// and lines up with the others. Takes the foreground style like any text.
struct LucideGlyph: View {
    @Environment(LucideModel.self) private var model
    let icon: LucideIcon
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            if let fontName = model.fontName {
                Text(verbatim: icon.glyph)
                    .font(.custom(fontName, fixedSize: size))
                    .lineLimit(1)
                    .fixedSize()
                    .id(model.fontGeneration)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: icon.name))
    }
}
