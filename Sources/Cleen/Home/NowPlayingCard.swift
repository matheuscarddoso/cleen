import AppKit
import SwiftUI

/// The player, laid out like NotchNook's: artwork with the playing app's icon on its
/// corner, title / album / artist stacked beside it, and three small controls.
struct NowPlayingCard: View {
    @Environment(NowPlayingModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            NowPlayingArtwork(image: model.artwork, appURL: model.appURL, isIcon: model.artworkIsIcon)
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.track?.title ?? "Nada tocando")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotchStyle.primary)
                Text(secondLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NotchStyle.primary.opacity(0.62))
                Text(thirdLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NotchStyle.primary.opacity(0.45))
                NowPlayingControls(isPlaying: model.track?.isPlaying ?? false, isEnabled: model.track != nil)
                    .padding(.top, 2)
                    .padding(.leading, -6)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.smooth(duration: 0.3), value: model.track?.identity)
    }

    /// Album, or the app when there is none (a video in a browser).
    private var secondLine: String {
        guard let track = model.track else { return "Toque algo em qualquer app" }
        return track.album.isEmpty ? (model.appName ?? "") : track.album
    }

    private var thirdLine: String {
        model.track?.artist ?? ""
    }
}
