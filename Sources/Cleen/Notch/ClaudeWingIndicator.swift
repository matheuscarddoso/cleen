import SwiftUI

/// Claude Code's own "working" glyph on the closed notch: the asterisk that keeps
/// turning into its cousins (· ✢ ✳ ✶ ✻ ✽ and back), in Claude's orange. When a turn
/// ends it becomes a green check for a moment (a red mark if it broke), then leaves. A
/// permission request or a question outranks both: Claude's mark, pulsing, until it's
/// answered.
struct ClaudeWingIndicator: View {
    let wing: AgentsModel.Wing
    var size = 14.0

    var body: some View {
        ZStack {
            switch wing {
            case .permission:
                ClaudeApprovalPulse(size: size, label: "Claude pede permissão")
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            case .question:
                ClaudeApprovalPulse(size: size, label: "Claude espera sua resposta")
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            case .working:
                ClaudeSpinner(size: size)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4).combined(with: .opacity),
                        removal: .scale(scale: 0.6).combined(with: .opacity)
                    ))
            case .ended(.done):
                endMark("checkmark.circle.fill", color: NotchStyle.good, label: "Sessão do Claude concluída")
            case .ended(.failed):
                endMark("exclamationmark.circle.fill", color: NotchStyle.critical, label: "Sessão do Claude parou num erro")
            }
        }
        .frame(width: size + 2, height: size + 2)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: wing)
    }

    private func endMark(_ symbol: String, color: Color, label: LocalizedStringKey) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.3).combined(with: .opacity),
                removal: .scale(scale: 0.7).combined(with: .opacity).combined(with: .modifier(active: Blurred(radius: 4), identity: Blurred(radius: 0)))
            ))
            .accessibilityLabel(label)
    }
}

/// The glyphs Claude Code cycles through while it works, forwards then back.
struct ClaudeSpinner: View {
    var size = 14.0

    private static let frames = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]
    private static let interval = 0.12

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.interval)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / Self.interval) % Self.frames.count
            Text(Self.frames[index])
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(ClaudeLogo.orange)
                .frame(width: size + 2, height: size + 2)
        }
        .accessibilityLabel("Claude trabalhando")
    }
}

/// Softens an icon on its way out.
private struct Blurred: ViewModifier {
    let radius: Double
    func body(content: Content) -> some View { content.blur(radius: radius) }
}
