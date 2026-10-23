import SwiftUI

/// Previous, play/pause, next — small glyphs with a round hover, as in NotchNook.
struct NowPlayingControls: View {
    @Environment(NowPlayingModel.self) private var model
    let isPlaying: Bool
    var isEnabled = true

    var body: some View {
        HStack(spacing: 4) {
            PlayerButton(symbol: "backward.end.fill", label: String(localized: "Anterior")) { send(.previous) }
            PlayerButton(symbol: isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? String(localized: "Pausar") : String(localized: "Tocar")) { send(.playPause) }
            PlayerButton(symbol: "forward.end.fill", label: String(localized: "Próxima")) { send(.next) }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }

    private func send(_ command: NowPlayingCommand) {
        Task { await model.send(command) }
    }
}
