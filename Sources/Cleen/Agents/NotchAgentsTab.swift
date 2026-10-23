import AppKit
import CleenKit
import SwiftUI

/// The Claude Code sessions that moved in the last half hour: what each is doing, and
/// which ones are waiting for you. Read from Claude Code's own transcripts.
struct NotchAgentsTab: View {
    @Environment(AgentsModel.self) private var agents

    var body: some View {
        Group {
            if !AgentsModel.isClaudeCodeInstalled {
                NotchPrompt(
                    symbol: "sparkles",
                    color: ToolPalette.orange,
                    title: String(localized: "Claude Code não encontrado"),
                    message: String(localized: "As sessões aparecem aqui assim que o Claude Code rodar neste Mac."),
                    buttonTitle: String(localized: "Procurar de novo")
                ) { Task { await agents.refresh() } }
            } else if agents.sessions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(NotchStyle.tertiary)
                    Text("Nenhuma sessão na última meia hora")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotchScroll {
                    NotchGroup {
                        ForEach(agents.sessions) { session in
                            AgentRow(session: session)
                        }
                    }
                }
            }
        }
        .task { await agents.refresh() }
    }
}

private struct AgentRow: View {
    let session: ClaudeSession
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ToolPalette.orange)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if let project = session.projectName {
                    Text(project)
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchStyle.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            AgentStateLabel(session: session)
            if isHovered, let directory = session.directory {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: directory)])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .buttonStyle(.plain)
                .help("Mostrar a pasta no Finder")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(isHovered ? NotchStyle.control.opacity(0.5) : .clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
    }
}
