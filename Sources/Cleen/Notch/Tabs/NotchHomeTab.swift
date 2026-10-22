import SwiftUI

/// The notch's front page, as in OmniNotch: a greeting, what's playing, and the day.
struct NotchHomeTab: View {
    @Environment(NowPlayingModel.self) private var nowPlaying
    @Environment(AgendaModel.self) private var agenda

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotchGreeting()
            HStack(alignment: .top, spacing: 18) {
                NowPlayingCard()
                    .frame(width: 360)
                Rectangle()
                    .fill(NotchStyle.track)
                    .frame(width: 1, height: 104)
                AgendaColumn()
            }
            .padding(.top, 4)
        }
        .task { await nowPlaying.watch() }
        .task { await agenda.watch() }
    }
}
