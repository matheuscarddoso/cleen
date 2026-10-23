import CleenKit
import SwiftUI

/// A Claude Code permission request, answered from the notch: which session asks, what
/// it wants to run or touch, and the same three answers the terminal offers. Return
/// allows; Esc leaves it to the terminal.
struct ClaudeApprovalCard: View {
    let approval: ClaudeApproval
    /// Requests behind this one.
    let queued: Int
    @Environment(AgentsModel.self) private var agents
    @FocusState private var isFocused: Bool

    /// A Return already on its way when the card appeared isn't an answer to it.
    private static let returnDelay = 0.6

    var body: some View {
        let request = approval.request
        let summary = request.summary
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                ClaudeLogo(size: 16)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(agents.title(for: approval))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(Self.asking(summary.kind))
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchStyle.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if queued > 0 {
                    Text(verbatim: "+\(queued)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(NotchStyle.secondary)
                        .padding(.horizontal, 6)
                        .frame(height: 16)
                        .background(NotchStyle.control, in: .capsule)
                        .help(String(localized: "Mais \(queued) pedidos esperando"))
                }
                ApprovalCountdown(approval: approval)
            }
            subject(summary)
            HStack(spacing: 6) {
                if let detail = summary.detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchStyle.tertiary)
                        .lineLimit(1)
                        .help(detail)
                }
                Spacer(minLength: 8)
                Button("Negar") { agents.deny(approval) }
                    .buttonStyle(.notchSecondary)
                if let rule = request.alwaysAllowDescription {
                    Button("Permitir sempre") { agents.approve(approval, always: true) }
                        .buttonStyle(.notchSecondary)
                        .help(String(localized: "Permite e não pergunta de novo: \(rule)"))
                }
                Button { agents.approve(approval) } label: {
                    HStack(spacing: 5) {
                        Text("Permitir")
                        Image(systemName: "return")
                            .font(.system(size: 9.5, weight: .medium))
                            .opacity(0.45)
                    }
                }
                .buttonStyle(.notchPrimary)
            }
        }
        .padding(10)
        .background(NotchStyle.card, in: .rect(cornerRadius: NotchStyle.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NotchStyle.cardRadius, style: .continuous)
                .strokeBorder(ClaudeLogo.orange.opacity(0.32))
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.return) {
            guard Date.now.timeIntervalSince(approval.arrivedAt) > Self.returnDelay else { return .handled }
            agents.approve(approval)
            return .handled
        }
        // Same settling delay as the other tabs' focus: taking it on the panel's opening
        // frame stalls the spring.
        .task(id: approval.id) {
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Pedido de permissão do Claude Code"))
    }

    /// What's being asked for, as the terminal would show it: the command after a
    /// prompt sign, a path that keeps its file name when it doesn't fit.
    private func subject(_ summary: ClaudeToolSummary) -> some View {
        let isCommand = summary.kind == .command
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            if isCommand {
                Text(verbatim: "$")
                    .foregroundStyle(NotchStyle.tertiary)
            }
            Text(verbatim: summary.subject)
                .foregroundStyle(NotchStyle.primary.opacity(0.9))
                .lineLimit(isCommand ? 2 : 1)
                .truncationMode(isCommand ? .tail : .middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(summary.isCode ? .system(size: 11.5, design: .monospaced) : .system(size: 12))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(NotchStyle.control.opacity(0.55), in: .rect(cornerRadius: 8, style: .continuous))
        .help(summary.subject)
    }

    private static func asking(_ kind: ClaudeToolSummary.Kind) -> String {
        switch kind {
        case .command: String(localized: "Quer rodar um comando")
        case .edit: String(localized: "Quer editar um arquivo")
        case .write: String(localized: "Quer escrever um arquivo")
        case .read: String(localized: "Quer ler um arquivo")
        case .fetch: String(localized: "Quer abrir um endereço")
        case .search: String(localized: "Quer fazer uma busca")
        case .agent: String(localized: "Quer iniciar um agente")
        case .mcp(let server, let tool): String(localized: "Quer usar \(tool) do \(server)")
        case .other(let tool): String(localized: "Quer usar \(tool)")
        }
    }
}

/// The time left before the request goes back to the terminal, as a ring that empties.
private struct ApprovalCountdown: View {
    let approval: ClaudeApproval
    @State private var left = 1.0

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.track, lineWidth: 2)
            Circle()
                .trim(from: 0, to: left)
                .stroke(NotchStyle.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 12, height: 12)
        .help("Sem resposta, o pedido volta para o terminal")
        .accessibilityHidden(true)
        .task(id: approval.id) {
            let total = approval.expiresAt.timeIntervalSince(approval.arrivedAt)
            let remaining = max(0, approval.expiresAt.timeIntervalSinceNow)
            left = total > 0 ? remaining / total : 0
            withAnimation(.linear(duration: remaining)) { left = 0 }
        }
    }
}

/// Claude's mark on the closed notch with a ring going out from it: a session is
/// waiting for permission. Holds still under Reduce Motion.
struct ClaudeApprovalPulse: View {
    var size = 14.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion {
                // A ring every 1.5 s, quick out of the gate and fading as it grows.
                TimelineView(.animation(minimumInterval: 1 / 40)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5
                    let eased = 1 - pow(1 - t, 3)
                    Circle()
                        .stroke(ClaudeLogo.orange, lineWidth: 1.5)
                        .scaleEffect(0.85 + 1.05 * eased)
                        .opacity(0.8 * (1 - t))
                }
            }
            ClaudeLogo(size: size)
        }
        .frame(width: size + 2, height: size + 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude pede permissão")
    }
}
