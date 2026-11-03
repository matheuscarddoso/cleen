import CleenKit
import SwiftUI

/// "Rodando um comando · 12 s", "Esperando sua resposta", "Sua vez", with a dot that
/// says at a glance whose move it is.
struct AgentStateLabel: View {
    let session: ClaudeSession
    var showsElapsed = true
    @Environment(AgentsModel.self) private var agents

    var body: some View {
        let status = agents.status(of: session)
        HStack(spacing: 6) {
            AgentStateDot(tone: status.tone)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(text(of: status, at: context.date))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(status.tone.textColor)
                    .lineLimit(1)
            }
        }
    }

    private func text(of status: AgentStatus, at date: Date) -> String {
        guard showsElapsed, status.tone == .busy else { return status.title }
        return "\(status.title) · \(Self.elapsed(from: session.since, to: date))"
    }

    /// "12 s", "3 min", "1 h".
    static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 { return String(localized: "\(seconds) s") }
        if seconds < 3600 { return String(localized: "\(seconds / 60) min") }
        return String(localized: "\(seconds / 3600) h")
    }
}

/// A session as the person sees it: its transcript's state, or a permission request
/// the hook brought in (the transcript only knows a tool call is out).
enum AgentStatus: Equatable {
    case session(ClaudeSession.State)
    case permission

    /// Whose move it is, which decides the dot and the text's color.
    enum Tone: Equatable {
        /// Claude is at it.
        case busy
        /// Nothing moves until the person answers.
        case needsYou
        /// The turn is over; the next message is the person's.
        case yourTurn
        /// The person stopped it themselves: their turn, said quietly.
        case stopped
        case failed

        var dotColor: Color {
            switch self {
            case .busy, .needsYou: NotchStyle.warning
            case .yourTurn, .stopped: NotchStyle.good
            case .failed: NotchStyle.critical
            }
        }

        var textColor: Color {
            switch self {
            case .busy: NotchStyle.primary.opacity(0.85)
            case .needsYou: NotchStyle.warning
            case .yourTurn: NotchStyle.good
            case .stopped: NotchStyle.secondary
            case .failed: NotchStyle.critical
            }
        }
    }

    var tone: Tone {
        switch self {
        case .permission: .needsYou
        case .session(let state):
            switch state {
            case .thinking, .running, .delegating: .busy
            case .asking, .reviewingPlan: .needsYou
            case .waiting: .yourTurn
            case .interrupted: .stopped
            case .failed: .failed
            }
        }
    }

    var title: String {
        switch self {
        case .permission: String(localized: "Pedindo sua permissão")
        case .session(let state):
            switch state {
            case .thinking: String(localized: "Pensando")
            case .running(let tool): Self.title(of: ClaudeTool(name: tool))
            case .delegating(let agents, let workflows):
                if workflows > 0 {
                    workflows == 1 ? String(localized: "Workflow rodando") : String(localized: "\(workflows) workflows rodando")
                } else {
                    agents == 1 ? String(localized: "1 agente trabalhando") : String(localized: "\(agents) agentes trabalhando")
                }
            case .asking: String(localized: "Esperando sua resposta")
            case .reviewingPlan: String(localized: "Plano pronto pra revisar")
            case .waiting: String(localized: "Sua vez")
            case .interrupted: String(localized: "Interrompido")
            case .failed: String(localized: "Parou num erro")
            }
        }
    }

    private static func title(of tool: ClaudeTool) -> String {
        switch tool {
        case .command: String(localized: "Rodando um comando")
        case .reading: String(localized: "Lendo arquivos")
        case .editing: String(localized: "Editando arquivos")
        case .searching: String(localized: "Buscando no código")
        case .web: String(localized: "Pesquisando na web")
        case .agent: String(localized: "Delegando a um agente")
        case .workflow: String(localized: "Iniciando um workflow")
        case .skill: String(localized: "Usando uma skill")
        case .loadingTools: String(localized: "Carregando ferramentas")
        case .mcp(let server): String(localized: "Usando \(server)")
        case .other(let name): name.isEmpty ? String(localized: "Usando uma ferramenta") : String(localized: "Usando \(name)")
        }
    }
}

/// Orange and breathing while busy; orange, steady and ringed while it needs the
/// person; green once it's their turn; red when it broke.
struct AgentStateDot: View {
    let tone: AgentStatus.Tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if tone == .needsYou, !reduceMotion {
                // The approval's ring, small: the same call for attention as the notch's.
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5
                    Circle()
                        .stroke(tone.dotColor, lineWidth: 1.2)
                        .scaleEffect(1 + 1.1 * (1 - pow(1 - t, 3)))
                        .opacity(0.8 * (1 - t))
                }
                .frame(width: 7, height: 7)
            }
            // Breathes whenever it turns busy, not only if it was busy when it appeared.
            Circle()
                .fill(tone.dotColor)
                .frame(width: 7, height: 7)
                .phaseAnimator([1.0, 0.35]) { dot, opacity in
                    dot.opacity(tone == .busy && !reduceMotion ? opacity : 1)
                } animation: { _ in .easeInOut(duration: 0.9) }
        }
        .frame(width: 9, height: 9)
        .accessibilityHidden(true)
    }
}
