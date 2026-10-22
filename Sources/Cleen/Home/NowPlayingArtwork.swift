import AppKit
import SwiftUI

/// Album art or video thumbnail in a rounded square, with the playing app's icon
/// sitting on its bottom-right corner.
struct NowPlayingArtwork: View {
    let image: NSImage?
    let appURL: URL?

    var body: some View {
        Color(white: 0.16)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                }
            }
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if let appURL {
                    FileIcon(url: appURL, size: 30)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .offset(x: 7, y: 7)
                        .onTapGesture { NSWorkspace.shared.openApplication(at: appURL, configuration: .init()) }
                }
            }
            .accessibilityHidden(true)
    }
}
