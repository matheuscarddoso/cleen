import AppKit
import SwiftUI

/// The playing item's artwork, small, for the closed notch.
struct WingArtwork: View {
    let image: NSImage?
    var size = 20.0
    var cornerRadius = 6.0

    var body: some View {
        Color(white: 0.2)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .id(ObjectIdentifier(image))
                        .transition(.trackSwap)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
