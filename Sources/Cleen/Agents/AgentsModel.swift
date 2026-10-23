import CleenKit
import Foundation
import Observation

/// Claude Code sessions that moved in the last half hour, read from their transcripts
/// every few seconds. Nothing is installed in Claude Code and nothing is sent anywhere:
/// it only reads the files Claude Code already writes.
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
}
