import SwiftUI

/// The player at each size: the full NotchNook-style card, a compact one with the
/// controls underneath, or just the artwork with play/pause on hover.
struct NowPlayingWidget: View {
    let size: HomeWidgetSize
    @Environment(NowPlayingModel.self) private var model
    @State private var isHovered = false

    var body: some View {
        switch size {
        case .large:
            NowPlayingCard()
        case .medium:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    NowPlayingArtwork(image: model.artwork, appURL: model.appURL, isIcon: model.artworkIsIcon, side: 50)
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.track?.title ?? String(localized: "Nada tocando"))
                            .font(.system(size: 13, weight: .semibold))
                        Text(model.track.map { $0.artist.isEmpty ? (model.appName ?? "") : $0.artist } ?? String(localized: "Toque algo em qualquer app"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchStyle.primary.opacity(0.55))
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                NowPlayingControls(isPlaying: model.track?.isPlaying ?? false, isEnabled: model.track != nil)
                    .frame(maxWidth: .infinity)
            }
            .animation(.smooth(duration: 0.3), value: model.track?.identity)
        case .small:
            NowPlayingArtwork(image: model.artwork, appURL: nil, isIcon: model.artworkIsIcon)
                .frame(width: 88, height: 88)
                .overlay {
                    if isHovered, model.track != nil {
                        ZStack {
                            Color.black.opacity(0.45)
                            NowPlayingControls(isPlaying: model.track?.isPlaying ?? false)
                                .scaleEffect(0.82)
                        }
                        .clipShape(.rect(cornerRadius: 24, style: .continuous))
                        .transition(.opacity)
                    }
                }
                .onHover { hovering in withAnimation(.smooth(duration: 0.18)) { isHovered = hovering } }
                .help(model.track.map { "\($0.title) — \($0.artist)" } ?? String(localized: "Nada tocando"))
        }
    }
}
