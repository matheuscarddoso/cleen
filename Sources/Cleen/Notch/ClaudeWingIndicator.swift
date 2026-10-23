import SwiftUI

/// Claude Code's own "working" glyph on the closed notch: the asterisk that keeps
/// turning into its cousins (· ✢ ✳ ✶ ✻ ✽ and back), in Claude's orange. When a session
/// finishes it becomes a green check for a moment, then leaves. A permission request
/// outranks both: Claude's mark, pulsing, until it's answered.
struct ClaudeWingIndicator: View {
    let isWorking: Bool
    let justFinished: Bool
    var needsApproval = false
    var size = 14.0

    var body: some View {
        ZStack {
            if needsApproval {
                ClaudeApprovalPulse(size: size)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else if isWorking {
                ClaudeSpinner(size: size)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4).combined(with: .opacity),
                        removal: .scale(scale: 0.6).combined(with: .opacity)
                    ))
            } else if justFinished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, NotchStyle.good)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .scale(scale: 0.7).combined(with: .opacity).combined(with: .modifier(active: Blurred(radius: 4), identity: Blurred(radius: 0)))
                    ))
                    .accessibilityLabel("Sessão do Claude concluída")
            }
        }
        .frame(width: size + 2, height: size + 2)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isWorking)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: justFinished)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: needsApproval)
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
