import CleenKit
import SwiftUI

/// "Rodando Bash · 12 s", "Pensando", "Esperando você", with a dot that breathes while
/// the session works.
struct AgentStateLabel: View {
    let session: ClaudeSession
    var showsElapsed = true

    var body: some View {
        HStack(spacing: 6) {
            AgentStateDot(state: session.state)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(text(at: context.date))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(session.state.isBusy ? NotchStyle.primary.opacity(0.85) : NotchStyle.good)
                    .lineLimit(1)
            }
        }
    }

    private func text(at date: Date) -> String {
        let state: String = switch session.state {
        case .thinking: String(localized: "Pensando")
        case .running(let tool): tool.isEmpty ? String(localized: "Usando uma ferramenta") : String(localized: "Rodando \(tool)")
        case .waiting: String(localized: "Esperando você")
        }
        guard showsElapsed, session.state.isBusy else { return state }
        return "\(state) · \(Self.elapsed(from: session.since, to: date))"
    }

    /// "12 s", "3 min", "1 h".
    static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 { return String(localized: "\(seconds) s") }
        if seconds < 3600 { return String(localized: "\(seconds / 60) min") }
        return String(localized: "\(seconds / 3600) h")
    }
}

/// Orange and breathing while busy, green once it's the person's turn.
struct AgentStateDot: View {
    let state: ClaudeSession.State
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(state.isBusy ? NotchStyle.warning : NotchStyle.good)
            .frame(width: 7, height: 7)
            .opacity(state.isBusy && pulse ? 0.35 : 1)
            .animation(state.isBusy ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }
}
