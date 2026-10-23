import AppKit
import SwiftUI

/// Anthropic's Claude mark, wherever Cleen shows Claude. In color by default; with a
/// tint it takes the surrounding text color (the tab bar's monochrome icons).
struct ClaudeLogo: View {
    var size = 16.0
    var tint: Color?

    /// Stands for the logo where a view takes an SF Symbol name.
    static let symbolName = "cleen.claude"

    /// Claude's own orange, from the logo.
    static let orange = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)

    private static let image: NSImage? = Bundle.main.url(forResource: "claude", withExtension: "svg").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        Group {
            if let image = Self.image {
                if let tint {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(tint)
                } else {
                    Image(nsImage: image)
                        .resizable()
                }
            } else {
                Image(systemName: "asterisk")
                    .resizable()
                    .foregroundStyle(tint ?? Self.orange)
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
        .accessibilityLabel("Claude")
    }
}
