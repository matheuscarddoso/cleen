import SwiftUI

/// The notch's front page, as in OmniNotch: a greeting, what's playing, and the day.
struct NotchHomeTab: View {
    @Environment(NowPlayingModel.self) private var nowPlaying
    @Environment(AgendaModel.self) private var agenda

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotchGreeting()
            HStack(alignment: .center, spacing: 16) {
                NowPlayingCard()
                    .frame(width: 270)
                Rectangle()
                    .fill(NotchStyle.track)
                    .frame(width: 1, height: 88)
                NotchCalendar()
                Rectangle()
                    .fill(NotchStyle.track)
                    .frame(width: 1, height: 88)
                MirrorButton()
            }
            .padding(.top, 4)
        }
        .task { await nowPlaying.watch() }
        .task { await agenda.watch() }
    }
}
