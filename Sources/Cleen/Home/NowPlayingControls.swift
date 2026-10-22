import SwiftUI

struct NowPlayingControls: View {
    @Environment(NowPlayingModel.self) private var model
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 22) {
            Spacer(minLength: 0)
            PlayerButton(symbol: "backward.fill", label: "Anterior", size: 17) { send(.previous) }
            PlayerButton(symbol: isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pausar" : "Tocar", size: 22) { send(.playPause) }
            PlayerButton(symbol: "forward.fill", label: "Próxima", size: 17) { send(.next) }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NotchStyle.tertiary)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                .accessibilityHidden(true)
        }
    }

    private func send(_ command: NowPlayingCommand) {
        Task { await model.send(command) }
    }
}
