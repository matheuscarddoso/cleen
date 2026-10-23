import AppKit
import SwiftUI

struct ScreenshotPreview: View {
    let shot: Screenshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.white.opacity(0.04)
                .overlay {
                    ThumbnailImage(url: shot.url, mode: .fit)
                }
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(NotchStyle.cardStroke)
                }
                // Drag it straight into Slack, Mail, a Finder window…
                .draggable(shot.url)
                .onTapGesture(count: 2) { NSWorkspace.shared.open(shot.url) }
                .help("Arraste para qualquer app · dois cliques para abrir")
            Text(shot.date.relative)
                .font(.system(size: 10))
                .foregroundStyle(NotchStyle.tertiary)
        }
    }
}
