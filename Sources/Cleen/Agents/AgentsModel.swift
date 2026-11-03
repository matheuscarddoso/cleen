import AppKit
import CleenKit
import Foundation
import Observation

/// Claude Code sessions that moved in the last half hour, read from their transcripts
/// every few seconds. Nothing is sent anywhere: it reads the files Claude Code already
/// writes. The one thing installed in Claude Code is opt-in (Ajustes › Claude Code): a
/// hook that brings its permission requests to the notch.
@Observable
final class AgentsModel {
    private(set) var sessions: [ClaudeSession] = []
    /// A busy session's turn just ended: the closed notch shows how for a moment.
    private(set) var justEnded: TurnEnd?
    @ObservationIgnored private var endedTask: Task<Void, Never>?
    /// Told when a busy session stops and wants the person: its turn ended, it asks
    /// something, or it hit an error.
    @ObservationIgnored var onFinished: (ClaudeSession) -> Void = { _ in }
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// Agentes is on screen: the steps are read often enough to follow along.
    @ObservationIgnored var isWatching = false
    @ObservationIgnored private let scanner = ClaudeSessionScanner()

    /// Busy sessions first, then the ones waiting, newest first within each.
    var working: [ClaudeSession] { sessions.filter(\.state.isBusy) }

    /// Any Claude Code config on this Mac has sessions: `~/.claude`, a second one beside
    /// it, or `$CLAUDE_CONFIG_DIR`.
    static var isClaudeCodeInstalled: Bool {
        !ClaudeSessionScanner.projectFolders(home: Paths.home, configDir: ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]).isEmpty
    }

    /// How a session reads right now: a permission request waiting in the notch outranks
    /// what its transcript says (a tool call that's out).
    func status(of session: ClaudeSession) -> AgentStatus {
        approvals.contains { $0.request.sessionID == session.id } ? .permission : .session(session.state)
    }

    /// How a turn that kept the person waiting ended, worth a glance on the closed notch.
    enum TurnEnd: Equatable {
        /// Claude finished: their turn.
        case done
        /// It stopped on an API error (a limit, an overload).
        case failed
    }

    /// What Claude's glyph on the closed notch says, most pressing first.
    enum Wing: Equatable {
        /// A permission request waits in the notch.
        case permission
        /// A session asked a question or has a plan to review.
        case question
        case working
        case ended(TurnEnd)
    }

    /// The glyph to show, if any. `showingSessions` is the person's switch for Claude in
    /// the live activities; a permission request shows regardless, since it holds a
    /// session up until it's answered here.
    func wing(showingSessions: Bool) -> Wing? {
        if !approvals.isEmpty { return .permission }
        guard showingSessions else { return nil }
        // A question stays up until it's answered: it isn't a moment's news like an end.
        if sessions.contains(where: \.state.needsAnswer) { return .question }
        if !working.isEmpty { return .working }
        return justEnded.map(Wing.ended)
    }

    /// A finished session's check, for checking the UI (`--live agent`).
    func previewFinished() { showEnded(.done) }

    func start() {
        Task { await refreshHook() }
        guard loop == nil, Self.isClaudeCodeInstalled else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                // Live while watched at work, quick while something runs, relaxed when quiet.
                let pause = self.working.isEmpty ? 10.0 : (self.isWatching ? 1.0 : 3.0)
                try? await Task.sleep(for: .seconds(pause))
            }
        }
    }

    func refresh() async {
        let scanner = scanner
        let found = await offMain { scanner.scan() }
        let before = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.state) })
        if found != sessions { sessions = found }
        // A busy session whose turn ended, that asks something or broke wants the person;
        // one they interrupted themselves doesn't.
        let landed = found.filter { $0.state.callsForThePerson && before[$0.id]?.isBusy == true }
        for session in landed { onFinished(session) }
        // Only an end flashes, and an error never as a check. A question or a plan has
        // the wing's needs-you pulse for as long as it waits instead.
        let end: TurnEnd? = if landed.contains(where: { $0.state == .failed }) {
            .failed
        } else if landed.contains(where: { $0.state == .waiting }) {
            .done
        } else {
            nil
        }
        if let end, working.isEmpty { showEnded(end) }
    }

    /// The mark stays long enough to be seen, then goes.
    private func showEnded(_ end: TurnEnd) {
        endedTask?.cancel()
        justEnded = end
        endedTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.justEnded = nil
        }
    }

    // MARK: Permission requests

    /// Requests waiting for an answer, oldest first. The notch shows the first.
    private(set) var approvals: [ClaudeApproval] = []
    private(set) var hookStatus = ClaudeHookInstaller.Status.notInstalled
    /// What went wrong the last time the hook was installed, removed or started.
    private(set) var hookProblem: HookProblem?
    private(set) var isChangingHook = false
    /// A request arrived: the notch opens on Agentes.
    @ObservationIgnored var onApprovalRequested: () -> Void = {}
    /// Nothing is waiting anymore.
    @ObservationIgnored var onApprovalsCleared: () -> Void = {}
    @ObservationIgnored private var server: HookSocketServer?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?
    @ObservationIgnored private let installer = ClaudeHookInstaller.standard

    /// A little under the hook's own limit, so Claude Code always hears "no decision"
    /// from Cleen before it would cancel the hook.
    static let approvalLifetime = TimeInterval(ClaudeHookSettings.timeout - 10)

    enum HookProblem: Equatable {
        case install(ClaudeHookInstaller.Failure)
        case listen(HookSocketServer.StartError)
    }

    func approve(_ approval: ClaudeApproval, always: Bool = false) {
        if always, let rule = approval.request.alwaysAllowRule {
            answer(approval, with: .allowAlways(rule: rule))
        } else {
            answer(approval, with: .allow)
        }
    }

    func deny(_ approval: ClaudeApproval) { answer(approval, with: .deny) }

    /// Leaves the decision to the terminal: Claude Code shows its own prompt.
    func dismiss(_ approval: ClaudeApproval) { answer(approval, with: nil) }

    /// The session's own title, else its folder.
    func title(for approval: ClaudeApproval) -> String {
        sessions.first { $0.id == approval.request.sessionID }?.title
            ?? approval.request.projectName
            ?? "Claude Code"
    }

    func installHook() async {
        await changeHook { (installer) throws(ClaudeHookInstaller.Failure) in try installer.install() }
    }

    func removeHook() async {
        // Whatever is waiting goes back to its terminal first.
        stopListening()
        await changeHook { (installer) throws(ClaudeHookInstaller.Failure) in try installer.uninstall() }
    }

    func refreshHook() async {
        let installer = installer
        let status = await offMain { installer.status() }
        if status != hookStatus { hookStatus = status }
        status == .installed ? listen() : stopListening()
    }

    private func changeHook(_ work: @escaping @Sendable (ClaudeHookInstaller) throws(ClaudeHookInstaller.Failure) -> Void) async {
        guard !isChangingHook else { return }
        isChangingHook = true
        hookProblem = nil
        let installer = installer
        let result = await offMain { Result<Void, ClaudeHookInstaller.Failure> { () throws(ClaudeHookInstaller.Failure) in try work(installer) } }
        if case .failure(let failure) = result { hookProblem = .install(failure) }
        await refreshHook()
        isChangingHook = false
    }

    private func answer(_ approval: ClaudeApproval, with decision: ClaudePermissionDecision?) {
        guard let index = approvals.firstIndex(where: { $0.id == approval.id }) else { return }
        approvals.remove(at: index)
        server?.respond(approval.id, body: decision?.output)
        if approvals.isEmpty { onApprovalsCleared() }
    }

    private func listen() {
        guard server == nil else { return }
        let server = HookSocketServer(
            path: installer.socket.path(percentEncoded: false),
            lifetime: Self.approvalLifetime,
            onRequest: { [weak self] id, body in
                // Decoded here, off the main thread: a Write carries the whole file.
                let request = ClaudePermissionRequest(json: body)
                Task { @MainActor in self?.received(id, request) }
            },
            onGone: { [weak self] id in
                Task { @MainActor in self?.gone(id) }
            }
        )
        do {
            try server.start()
        } catch {
            hookProblem = .listen(error)
            return
        }
        if case .listen? = hookProblem { hookProblem = nil }
        self.server = server
        // Quitting hands every waiting request back to its terminal at once, and takes
        // the socket away so the hook stops trying.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopListening() }
        }
    }

    private func stopListening() {
        guard let server else { return }
        self.server = nil
        server.stop()
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        terminationObserver = nil
        if !approvals.isEmpty {
            approvals.removeAll()
            onApprovalsCleared()
        }
    }

    private func received(_ id: UUID, _ request: ClaudePermissionRequest?) {
        guard let request else {
            server?.respond(id, body: nil)
            return
        }
        let now = Date.now
        approvals.append(ClaudeApproval(id: id, request: request, arrivedAt: now, expiresAt: now.addingTimeInterval(Self.approvalLifetime)))
        onApprovalRequested()
    }

    /// Answered in the terminal, or it ran out of time.
    private func gone(_ id: UUID) {
        guard let index = approvals.firstIndex(where: { $0.id == id }) else { return }
        approvals.remove(at: index)
        if approvals.isEmpty { onApprovalsCleared() }
    }
}

/// A Claude Code permission request waiting in the notch.
struct ClaudeApproval: Identifiable, Equatable {
    let id: UUID
    let request: ClaudePermissionRequest
    let arrivedAt: Date
    let expiresAt: Date
}
