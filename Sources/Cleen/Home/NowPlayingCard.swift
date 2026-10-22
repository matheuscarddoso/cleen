import AppKit
import SwiftUI

/// The player card: artwork, title, a live playhead and the three controls, tinted by
/// the album's own color.
struct NowPlayingCard: View {
    @Environment(NowPlayingModel.self) private var model

    var body: some View {
        HStack(spacing: 14) {
            NowPlayingArtwork(image: model.artwork)
                .frame(width: 112, height: 112)
            if let track = model.track {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(subtitle(for: track))
                                .font(NotchStyle.body)
                                .foregroundStyle(NotchStyle.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if let app = model.appURL {
                            FileIcon(url: app, size: 20)
                                .onTapGesture { NSWorkspace.shared.openApplication(at: app, configuration: .init()) }
                                .help("Abrir o \(model.appName ?? "app")")
                        }
                    }
                    Spacer(minLength: 8)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        NowPlayingProgress(position: model.position(at: context.date), duration: track.duration)
                    }
                    Spacer(minLength: 6)
                    NowPlayingControls(isPlaying: track.isPlaying)
                }
                .frame(height: 112)
            } else {
                NowPlayingEmpty()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: .rect(cornerRadius: NotchStyle.cardRadius + 2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NotchStyle.cardRadius + 2, style: .continuous)
                .strokeBorder(NotchStyle.cardStroke)
        }
        .animation(.smooth(duration: 0.4), value: model.track?.identity)
    }

    /// "Artista · App", leaving out whatever is missing (videos often have no artist).
    private func subtitle(for track: NowPlayingTrack) -> String {
        [track.artist, model.appName ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The album's average color, pushed dark, fading into the card grey.
    private var background: LinearGradient {
        let base = Color(white: 0.11)
        guard let tint = model.tint else { return NotchStyle.card }
        let deep = Color(nsColor: tint.blended(withFraction: 0.62, of: .black) ?? tint)
        return LinearGradient(colors: [deep, base], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
