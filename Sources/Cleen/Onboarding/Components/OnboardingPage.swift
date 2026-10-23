import SwiftUI

/// The left half of every page: progress, a headline, one paragraph, the page's own
/// controls, and the buttons at the bottom. Pieces arrive one after another.
struct OnboardingPage<Content: View>: View {
    let title: String
    let message: String
    let primary: String
    var secondary: String?
    var footnote: String?
    var onPrimary: (() -> Void)?
    var onSecondary: (() -> Void)?
    @ViewBuilder let content: Content
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .onboardingReveal(0)
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .padding(.top, 26)
                .onboardingReveal(1)
            Text(message)
                .font(.system(size: 14.5))
                .foregroundStyle(NotchStyle.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .onboardingReveal(2)
            content
                .padding(.top, 24)
                .onboardingReveal(3)
            Spacer(minLength: 16)
            actions
                .onboardingReveal(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if model.step != .welcome {
                Button(action: model.back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Voltar")
                .accessibilityLabel("Voltar")
            }
            ProgressCapsule(progress: model.step.progress)
        }
        .frame(height: 22)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Button(primary) { (onPrimary ?? model.advance)() }
                    .buttonStyle(.onboardingPrimary)
                if let secondary {
                    Button(secondary) { (onSecondary ?? model.advance)() }
                        .buttonStyle(.onboardingSecondary)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
