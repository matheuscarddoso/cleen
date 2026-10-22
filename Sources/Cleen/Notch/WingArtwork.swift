import AppKit
import SwiftUI

/// The playing item's artwork, small, for the closed notch.
struct WingArtwork: View {
    let image: NSImage?

    var body: some View {
        Color(white: 0.2)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(.rect(cornerRadius: 5, style: .continuous))
            .accessibilityHidden(true)
    }
}
