import AppKit
import CleenKit
import SwiftUI

/// Claude Code at work, the way Droppy shows its agents: Progress has the session's
/// latest steps on the left (done ones checked, the current one playing) and the current
/// step's detail on the right (the file and its lines, the edit's +/−, the command and its
/// seconds, or what Claude is thinking); Usage has every tool's limits as rings. A
/// permission request, when the hook is on, comes first.
struct NotchAgentsTab: View {
    @Environment(AgentsModel.self) private var agents
    @Environment(NotchState.self) private var notch
    @State private var page = Page.progress
    @State private var focusedID: String?

    enum Page { case progress, usage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ZStack(alignment: .top) {
                switch page {
                case .progress: progress.transition(.toolSwap)
                case .usage: AgentUsageRings().transition(.toolSwap)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: agents.approvals.first?.id)
        .task { await agents.refresh() }
        .onAppear {
            agents.isWatching = true
            // Esc leaves the request to the terminal; with none left, it closes the notch.
            notch.escapeHandler = { [agents] in
                guard let approval = agents.approvals.first else { return false }
                agents.dismiss(approval)
                return !agents.approvals.isEmpty
            }
        }
        .onDisappear {
            agents.isWatching = false
            notch.escapeHandler = nil
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: page == .progress ? "list.bullet.indent" : "gauge.with.needle")
                .font(.system(size: 11, weight: .medium))
            Text(page == .progress ? "Progresso" : "Uso")
                .font(.system(size: 12, weight: .medium))
                .contentTransition(.opacity)
            Spacer()
            pageButton(.progress, symbol: "list.bullet.indent", help: "Progresso")
            pageButton(.usage, symbol: "gauge.with.needle", help: "Uso")
        }
        .foregroundStyle(NotchStyle.secondary)
        .animation(.smooth(duration: 0.2), value: page)
    }

    private func pageButton(_ target: Page, symbol: String, help: LocalizedStringKey) -> some View {
        let isOn = page == target
        return Button {
            withAnimation(.smooth(duration: 0.28)) { page = target }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isOn ? AgentPalette.green : NotchStyle.tertiary)
                .frame(width: 24, height: 24)
                .background(isOn ? AgentPalette.green.opacity(0.18) : NotchStyle.control.opacity(0.6), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var progress: some View {
        if let approval = agents.approvals.first {
            NotchScroll {
                ClaudeApprovalCard(approval: approval, queued: agents.approvals.count - 1)
                    .id(approval.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity), removal: .opacity))
            }
        } else if !AgentsModel.isClaudeCodeInstalled {
            NotchPrompt(
                symbol: "asterisk",
                color: ToolPalette.orange,
                title: String(localized: "Claude Code não encontrado"),
                message: String(localized: "As sessões aparecem aqui assim que o Claude Code rodar neste Mac."),
                buttonTitle: String(localized: "Procurar de novo")
            ) { Task { await agents.refresh() } }
        } else if let session = focused {
            AgentSessionView(session: session, position: position(of: session), total: agents.sessions.count) { step in
                move(by: step)
            }
        } else {
            VStack(spacing: 6) {
                ClaudeLogo(size: 18).opacity(0.5)
                Text("Nenhuma sessão na última meia hora")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The session picked with the arrows, else the first one at work, else the newest.
    private var focused: ClaudeSession? {
        if let focusedID, let session = agents.sessions.first(where: { $0.id == focusedID }) { return session }
        return agents.working.first ?? agents.sessions.first
    }

    private func position(of session: ClaudeSession) -> Int {
        (agents.sessions.firstIndex { $0.id == session.id } ?? 0) + 1
    }

    private func move(by step: Int) {
        guard let current = focused, let index = agents.sessions.firstIndex(where: { $0.id == current.id }) else { return }
        let next = (index + step + agents.sessions.count) % agents.sessions.count
        withAnimation(.smooth(duration: 0.3)) { focusedID = agents.sessions[next].id }
    }
}

enum AgentPalette {
    static let orange = Color(red: 0.98, green: 0.52, blue: 0.24)
    static let green = Color(red: 0.36, green: 0.84, blue: 0.52)
    static let red = Color(red: 1.0, green: 0.4, blue: 0.4)
}

/// One session: who and what, its steps, and the current step's card.
private struct AgentSessionView: View {
    let session: ClaudeSession
    let position: Int
    let total: Int
    let move: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ClaudeLogo(size: 17, tint: ClaudeLogo.orange)
                Text(verbatim: "Claude")
                    .font(.system(size: 15, weight: .semibold))
                Circle().fill(AgentPalette.orange).frame(width: 5, height: 5)
                Text(session.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AgentPalette.orange)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Spacer(minLength: 8)
                if total > 1 {
                    HStack(spacing: 2) {
                        arrow("chevron.left") { move(-1) }
                        Text(verbatim: "\(position)/\(total)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(NotchStyle.tertiary)
                        arrow("chevron.right") { move(1) }
                    }
                }
            }
            HStack(alignment: .top, spacing: 14) {
                AgentStepList(session: session)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AgentStepCard(session: session)
                    .frame(width: 236)
            }
        }
        .id(session.id)
        .transition(.toolSwap)
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 20, height: 20)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The last three steps: done ones checked, the running one playing in orange. New steps
/// rise in from below, old ones drift out at the top.
private struct AgentStepList: View {
    let session: ClaudeSession

    var body: some View {
        let steps = Array(session.activity.steps.suffix(3))
        VStack(alignment: .leading, spacing: 7) {
            if steps.isEmpty {
                row(symbol: session.state.isBusy ? "play.fill" : "checkmark", color: session.state.isBusy ? AgentPalette.orange : NotchStyle.primary,
                    title: session.state.isBusy ? String(localized: "Pensando…") : String(localized: "Pronto"))
                    .transition(.agentStep)
            }
            ForEach(steps) { step in
                let running = !step.isDone && session.state.isBusy
                row(symbol: running ? "play.fill" : "checkmark", color: running ? AgentPalette.orange : NotchStyle.primary, title: AgentStepText.title(of: step))
                    .transition(.agentStep)
            }
            if session.state == .thinking, steps.last?.isDone == true {
                row(symbol: "play.fill", color: AgentPalette.orange, title: String(localized: "Pensando…"))
                    .transition(.agentStep)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: steps.map(\.id))
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: session.state)
    }

    private func row(symbol: String, color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "play.fill" ? 9 : 10.5, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 12)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(NotchStyle.primary.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// The current step up close, as Droppy's card: the file and its length, an edit's
/// +/−, a command and its running seconds, or the sentence Claude is on.
private struct AgentStepCard: View {
    let session: ClaudeSession

    var body: some View {
        let current = session.activity.steps.last
        ZStack {
            if let current, session.state.isBusy, !current.isDone {
                detail(current).id(current.id).transition(.toolSwap)
            } else {
                note.id("note-\(session.activity.note ?? "")").transition(.toolSwap)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(Color.white.opacity(0.055), in: .rect(cornerRadius: 13, style: .continuous))
        .animation(.smooth(duration: 0.3), value: current?.id)
    }

    @ViewBuilder
    private var note: some View {
        if session.activity.note == nil, session.state.isBusy {
            ThinkingDots().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            noteText
        }
    }

    private var noteText: some View {
        let text = session.activity.note ?? String(localized: "Pronto. Esperando você.")
        return Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(NotchStyle.primary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func detail(_ step: ClaudeStep) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: AgentStepText.symbol(of: step))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AgentPalette.orange)
                Text(AgentStepText.subject(of: step))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(step.kind.isCommand ? NotchStyle.primary : AgentPalette.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if case .edit(_, let added, let removed) = step.kind {
                    HStack(spacing: 5) {
                        Text(verbatim: "+\(added)").foregroundStyle(AgentPalette.green)
                        Text(verbatim: "−\(removed)").foregroundStyle(AgentPalette.red)
                    }
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                }
            }
            metric(step)
            AgentProgressBar(start: step.startedAt)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func metric(_ step: ClaudeStep) -> some View {
        switch step.kind {
        case .read(_, let lines):
            if let lines {
                (Text("Linhas ").foregroundStyle(NotchStyle.tertiary) + Text(verbatim: "\(lines)").foregroundStyle(NotchStyle.primary))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            } else {
                caption(String(localized: "Lendo…"))
            }
        case .edit, .write:
            caption(String(localized: "Salvando…"))
        case .command:
            if let start = step.startedAt {
                TimelineView(.periodic(from: .now, by: 0.05)) { context in
                    Text(String(format: String(localized: "%.2f segundos"), max(0, context.date.timeIntervalSince(start))))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(NotchStyle.secondary)
                }
            } else {
                caption(String(localized: "Rodando…"))
            }
        case .search: caption(String(localized: "Procurando…"))
        case .web: caption(String(localized: "Abrindo…"))
        case .agent: caption(String(localized: "Um agente está nisso…"))
        case .other: caption(String(localized: "Em andamento…"))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NotchStyle.secondary)
    }
}

/// How far along a running step is: it fills from the left, quickly at first and slower
/// as it goes (no step says how long it'll take), with a bright head that glows and a
/// soft sheen running through the filled part.
private struct AgentProgressBar: View {
    let start: Date?

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = max(0, context.date.timeIntervalSince(start ?? context.date))
            // Eases toward the end without ever claiming it's done.
            let fraction = 0.06 + 0.88 * (1 - exp(-elapsed / 7))
            let sheen = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.2) / 2.2
            GeometryReader { proxy in
                let width = proxy.size.width * fraction
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [AgentPalette.orange.opacity(0.55), AgentPalette.orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width)
                        .overlay(alignment: .leading) {
                            // The sheen: a narrow light passing along the fill.
                            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 26)
                                .offset(x: (width + 26) * sheen - 26)
                        }
                        .clipShape(.capsule)
                    // The head, glowing.
                    Circle()
                        .fill(Color(red: 1, green: 0.84, blue: 0.68))
                        .frame(width: 5, height: 5)
                        .shadow(color: AgentPalette.orange, radius: 4)
                        .shadow(color: AgentPalette.orange.opacity(0.6), radius: 9)
                        .offset(x: max(0, width - 4))
                }
            }
        }
        .frame(height: 3)
    }
}

/// Three dots breathing in turn while Claude thinks without saying anything yet.
private struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    let wave = (sin((t * 2 * .pi / 1.2) - Double(index) * 0.9) + 1) / 2
                    Circle()
                        .fill(AgentPalette.orange.opacity(0.35 + 0.65 * wave))
                        .frame(width: 6, height: 6)
                        .scaleEffect(0.8 + 0.3 * wave)
                }
            }
        }
    }
}

/// How a step reads in the list and on the card.
enum AgentStepText {
    static func title(of step: ClaudeStep) -> String {
        switch step.kind {
        case .read: String(localized: "Ler \(step.fileName ?? "")")
        case .edit: String(localized: "Editar \(step.fileName ?? "")")
        case .write: String(localized: "Criar \(step.fileName ?? "")")
        // Claude's own short description reads best ("Build the app"); a bare command gets "Run".
        case .command(let command, let description):
            if let description, !description.isEmpty { description } else { String(localized: "Rodar \(short(command))") }
        case .search(let pattern): String(localized: "Buscar \(pattern)")
        case .web(let place): String(localized: "Abrir \(place)")
        case .agent(let description): String(localized: "Agente: \(description)")
        case .other(let tool): tool
        }
    }

    static func subject(of step: ClaudeStep) -> String {
        switch step.kind {
        case .read(let file, _), .edit(let file, _, _), .write(let file, _): URL(filePath: file).lastPathComponent
        case .command(let command, _): short(command)
        case .search(let pattern): pattern
        case .web(let place): place
        case .agent(let description): description
        case .other(let tool): tool
        }
    }

    static func symbol(of step: ClaudeStep) -> String {
        switch step.kind {
        case .read, .edit, .write: "doc.fill"
        case .command: "apple.terminal.fill"
        case .search: "magnifyingglass"
        case .web: "globe"
        case .agent: "person.2.fill"
        case .other: "wrench.and.screwdriver.fill"
        }
    }

    /// A command's first line, without the `cd …&&` in front, cut short.
    private static func short(_ command: String) -> String {
        var line = command.split(whereSeparator: \.isNewline).first.map(String.init) ?? command
        if line.hasPrefix("cd "), let and = line.range(of: "&& ") { line = String(line[and.upperBound...]) }
        return line.count > 38 ? String(line.prefix(36)) + "…" : line
    }
}

extension ClaudeStep.Kind {
    var isCommand: Bool {
        if case .command = self { return true }
        return false
    }
}

extension AnyTransition {
    /// A step rising into the list from below and drifting out at the top.
    static var agentStep: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .modifier(active: BlurEffect(radius: 5), identity: BlurEffect(radius: 0))),
            removal: .move(edge: .top).combined(with: .opacity).combined(with: .modifier(active: BlurEffect(radius: 5), identity: BlurEffect(radius: 0)))
        )
    }
}

/// Usage: each AI tool's tightest limit as a ring of what's left, Droppy's way.
private struct AgentUsageRings: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        let rings = items
        Group {
            if rings.isEmpty {
                Text("Os limites aparecem aqui assim que o Cleen conseguir lê-los.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 26) {
                    ForEach(rings, id: \.name) { ring in
                        VStack(spacing: 7) {
                            ZStack {
                                Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: ring.left)
                                    .stroke(ring.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                if ring.isClaude {
                                    ClaudeLogo(size: 20, tint: ClaudeLogo.orange)
                                } else {
                                    Image(systemName: ring.symbol)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(ring.color)
                                }
                            }
                            .frame(width: 54, height: 54)
                            VStack(spacing: 1) {
                                Text(ring.name).font(.system(size: 11.5, weight: .medium))
                                Text("\(Int((ring.left * 100).rounded()))% restante")
                                    .font(.system(size: 10.5).monospacedDigit())
                                    .foregroundStyle(NotchStyle.tertiary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: rings.map(\.left))
            }
        }
        .task { await model.refresh() }
    }

    private struct Ring {
        let name: String
        let symbol: String
        let color: Color
        let left: Double
        var isClaude = false
    }

    private var items: [Ring] {
        var rings: [Ring] = []
        if let windows = model.claude?.windows, let used = windows.map(\.used).max() {
            rings.append(Ring(name: "Claude", symbol: "", color: ClaudeLogo.orange, left: max(0, 1 - used), isClaude: true))
        }
        if let windows = model.codex, let used = windows.map(\.used).max() {
            rings.append(Ring(name: "Codex", symbol: "terminal", color: Color(red: 0.36, green: 0.55, blue: 1), left: max(0, 1 - used)))
        }
        for provider in model.providers {
            guard case .windows(let windows) = provider.state, let used = windows.map(\.used).max() else { continue }
            rings.append(Ring(name: provider.provider.name, symbol: provider.provider.symbol, color: Color.white.opacity(0.85), left: max(0, 1 - used)))
        }
        return rings
    }
}
