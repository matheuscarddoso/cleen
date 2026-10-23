import SwiftUI

/// The notch's front page, as in OmniNotch: a greeting, what's playing, the day, and
/// the mirror — which grows to fill the panel when tapped.
struct NotchHomeTab: View {
    @Environment(NowPlayingModel.self) private var nowPlaying
    @Environment(AgendaModel.self) private var agenda
    @Environment(NotchState.self) private var state
    @Namespace private var mirrorSpace

    var body: some View {
        ZStack(alignment: .top) {
            if state.mirrorExpanded {
                MirrorExpanded(namespace: mirrorSpace)
            } else {
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
                        MirrorButton(namespace: mirrorSpace)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: state.mirrorExpanded)
        .task { await nowPlaying.watch() }
        .task { await agenda.watch() }
    }
}
