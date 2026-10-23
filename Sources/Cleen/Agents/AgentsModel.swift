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
    /// A session just finished: the closed notch shows a check for a moment.
    private(set) var justFinished = false
    @ObservationIgnored private var finishedTask: Task<Void, Never>?
    /// Told when a session finishes a turn and starts waiting for the person.
    @ObservationIgnored var onFinished: (ClaudeSession) -> Void = { _ in }
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private let scanner = ClaudeSessionScanner()

    /// Busy sessions first, then the ones waiting, newest first within each.
    var working: [ClaudeSession] { sessions.filter(\.state.isBusy) }

    static var isClaudeCodeInstalled: Bool {
        FileManager.default.fileExists(atPath: Paths.home.appending(path: ".claude/projects").path(percentEncoded: false))
    }

    /// A finished session's check, for checking the UI (`--live agent`).
    func previewFinished() { showFinished() }

    func start() {
        Task { await refreshHook() }
        guard loop == nil, Self.isClaudeCodeInstalled else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                // Quick while something is running, relaxed when it's all quiet.
                try? await Task.sleep(for: .seconds(self.working.isEmpty ? 10 : 3))
            }
        }
    }

    func refresh() async {
        let scanner = scanner
        let found = await offMain { scanner.scan() }
        let before = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.state) })
        if found != sessions { sessions = found }
        let finished = found.filter { $0.state == .waiting && before[$0.id]?.isBusy == true }
        for session in finished { onFinished(session) }
        if !finished.isEmpty, working.isEmpty { showFinished() }
    }

    /// The check stays long enough to be seen, then goes.
    private func showFinished() {
        finishedTask?.cancel()
        justFinished = true
        finishedTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.justFinished = false
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
