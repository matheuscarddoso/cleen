import AppKit
import CleenKit
import SwiftUI

/// The Claude Code sessions that moved in the last half hour: what each is doing, and
/// which ones are waiting for you. Read from Claude Code's own transcripts. A permission
/// request, when the hook is on, comes first.
struct NotchAgentsTab: View {
    @Environment(AgentsModel.self) private var agents
    @Environment(NotchState.self) private var notch

    var body: some View {
        Group {
            if let approval = agents.approvals.first {
                // The request on top; the sessions stay below, a scroll away.
                NotchScroll {
                    VStack(spacing: 8) {
                        ClaudeApprovalCard(approval: approval, queued: agents.approvals.count - 1)
                            .id(approval.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        if !agents.sessions.isEmpty { sessionList }
                    }
                }
            } else if !AgentsModel.isClaudeCodeInstalled {
                NotchPrompt(
                    symbol: "asterisk",
                    color: ToolPalette.orange,
                    title: String(localized: "Claude Code não encontrado"),
                    message: String(localized: "As sessões aparecem aqui assim que o Claude Code rodar neste Mac."),
                    buttonTitle: String(localized: "Procurar de novo")
                ) { Task { await agents.refresh() } }
            } else if agents.sessions.isEmpty {
                VStack(spacing: 6) {
                    ClaudeLogo(size: 18)
                        .opacity(0.5)
                    Text("Nenhuma sessão na última meia hora")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotchScroll { sessionList }
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: agents.approvals.first?.id)
        .task { await agents.refresh() }
        .onAppear {
            // Esc leaves the request to the terminal; with none left, it closes the notch.
            notch.escapeHandler = { [agents] in
                guard let approval = agents.approvals.first else { return false }
                agents.dismiss(approval)
                return !agents.approvals.isEmpty
            }
        }
        .onDisappear { notch.escapeHandler = nil }
    }

    private var sessionList: some View {
        NotchGroup {
            ForEach(agents.sessions) { session in
                AgentRow(session: session)
            }
        }
    }
}

private struct AgentRow: View {
    let session: ClaudeSession
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ClaudeLogo(size: 15)
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
