import CleenKit
import SwiftUI

/// The newest Claude Code sessions on Início, and how many are working. A tap opens
/// Agentes.
struct AgentsWidget: View {
    let size: HomeWidgetSize
    @Environment(AgentsModel.self) private var agents
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .agents } label: {
            switch size {
            case .small:
                VStack(spacing: 4) {
                    ClaudeLogo(size: 22)
                    // Working ones when any are, otherwise the open ones waiting for you.
                    Text((agents.working.isEmpty ? agents.sessions.count : agents.working.count).formatted())
                        .font(.system(size: 22, weight: .light).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(smallCaption)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .frame(width: 88, height: 88)
            case .medium, .large:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        ClaudeLogo(size: 11)
                        Text("Claude Code")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    if agents.sessions.isEmpty {
                        Text("Nenhuma sessão agora")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchStyle.secondary)
                    } else {
                        ForEach(agents.sessions.prefix(size == .large ? 3 : 2)) { session in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(session.title)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .lineLimit(1)
                                AgentStateLabel(session: session, showsElapsed: size == .large)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .help("Abrir Agentes")
    }

    private var smallCaption: String {
        if !agents.working.isEmpty { return String(localized: "trabalhando") }
        return agents.sessions.isEmpty ? String(localized: "sem sessões") : String(localized: "esperando você")
    }
}
