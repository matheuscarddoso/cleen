import SwiftUI

/// The opening titles: a credit, then the wordmark rising letter by letter with a band
/// of light passing over it, then the line that says what Cleen is for.
struct OnboardingTitles: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        ZStack {
            credit
                .opacity(model.beat == .credit ? 1 : 0)
                .blur(radius: model.beat == .credit ? 0 : 8)
                .scaleEffect(model.beat == .credit ? 1 : 0.97)
            wordmark
                .opacity(model.beat == .wordmark ? 1 : 0)
                .blur(radius: model.beat > .wordmark ? 14 : 0)
                .scaleEffect(model.beat > .wordmark ? 1.06 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var credit: some View {
        VStack(spacing: 6) {
            Text("Matheus Cardoso")
                .font(.system(size: 16, weight: .medium))
                .tracking(0.2)
            Text("apresenta")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.6))
        }
        .shadow(color: .black.opacity(0.4), radius: 12)
    }

    private var wordmark: some View {
        VStack(spacing: 14) {
            Wordmark(text: "Cleen", isShown: model.beat >= .wordmark)
            Text("Seu Mac mais leve. Seu dia à mão.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.75))
                .opacity(model.beat >= .wordmark ? 1 : 0)
                .offset(y: model.beat >= .wordmark ? 0 : 8)
                .animation(.smooth(duration: 0.9).delay(0.75), value: model.beat)
        }
        .shadow(color: .black.opacity(0.35), radius: 20)
        .offset(y: -6)
    }
}
