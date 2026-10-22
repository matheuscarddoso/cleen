import AppKit
import SwiftUI

/// Album art or video thumbnail, filling a rounded square whatever its aspect ratio.
struct NowPlayingArtwork: View {
    let image: NSImage?

    var body: some View {
        Color(white: 0.17)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                }
            }
            .clipShape(.rect(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}
