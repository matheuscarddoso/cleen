import SwiftUI

/// Sound and skip, in the corner while the titles play.
struct TitleControls: View {
    static let height = 32.0
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            Button {
                model.isMuted.toggle()
            } label: {
                Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 34, height: Self.height)
            }
            .help(model.isMuted ? String(localized: "Ligar o som") : String(localized: "Tirar o som"))
            .accessibilityLabel(model.isMuted ? String(localized: "Ligar o som") : String(localized: "Tirar o som"))
            Button("Pular", action: model.skipTitles)
                .font(.system(size: 12, weight: .medium))
                .padding(.leading, 4)
                .padding(.trailing, 14)
                .frame(height: Self.height)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .background(.black.opacity(0.35), in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.12)) }
    }
}
