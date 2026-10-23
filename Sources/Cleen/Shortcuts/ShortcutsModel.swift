import AppKit
import CleenKit
import Observation

/// The person's Shortcuts and running them.
///
/// The library is read once per session through the `shortcuts` CLI (on first appear or
/// with the refresh button); runs go through the same CLI, one process per run, each
/// tracked on its own tile.
@Observable
final class ShortcutsModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum RunState: Equatable {
        case idle
        case running
        case done
        case failed(String)
    }

    struct Failure: Equatable {
        let id: String
        let name: String
        let message: String
    }

    private static let pinnedKey = "shortcutsPinned"
    /// Long enough for almost any shortcut; past it the spinner stops and the run is
    /// left alone, since a shortcut may legitimately wait on a dialog or a timer.
    private static let spinnerTimeout = Duration.seconds(60)

    private(set) var phase = Phase.idle
    /// A reload over a list that's already on screen (the toolbar shows a spinner).
    private(set) var isRefreshing = false
    private(set) var library = ShortcutLibrary(shortcuts: [])
    private(set) var pinned: Set<String>
    private(set) var states: [String: RunState] = [:]
    /// The most recent failure, spelled out in the tab's toolbar until it clears.
    private(set) var lastFailure: Failure?
    var query = ""
    var folderID: String?

    @ObservationIgnored private var runs: [String: Task<Void, Never>] = [:]
    /// Which run a tile's state belongs to: a result that arrives after a newer run (or a
    /// stop) started is dropped instead of overwriting it.
    @ObservationIgnored private var tokens: [String: Int] = [:]
    @ObservationIgnored private var nextToken = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init() {
        pinned = Set(UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? [])
    }

    /// What the grid shows right now.
    var visible: [ShortcutEntry] {
        library.arranged(pinned: pinned, query: query, folderID: folderID)
    }

    func state(of entry: ShortcutEntry) -> RunState {
        states[entry.id] ?? .idle
    }

    // MARK: Library

    /// Loads the library the first time the tab appears; later visits reuse it.
    func loadIfNeeded() {
        guard phase == .idle else { return }
        refresh()
    }

    func refresh() {
        guard loadTask == nil else { return }
        if library.shortcuts.isEmpty { phase = .loading } else { isRefreshing = true }
        loadTask = Task { [weak self] in
            let result = await Self.fetch()
            guard let self else { return }
            loadTask = nil
            isRefreshing = false
            switch result {
            case .success(let library):
                self.library = library
                if let folderID, !library.folders.contains(where: { $0.id == folderID }) { self.folderID = nil }
                phase = .loaded
            case .failure(let error):
                // Keep showing a list we already have; only an empty tab shows the error.
                phase = self.library.shortcuts.isEmpty ? .failed(error.localizedDescription) : .loaded
            }
        }
    }

    private nonisolated static func fetch() async -> Result<ShortcutLibrary, any Error> {
        do { return .success(try await ShortcutsCLI.library()) } catch { return .failure(error) }
    }

    // MARK: Running

    func run(_ entry: ShortcutEntry) {
        if state(of: entry) == .running { return }
        nextToken += 1
        let token = nextToken
        let id = entry.id
        tokens[id] = token
        states[id] = .running
        if lastFailure?.id == id { lastFailure = nil }
        runs[id] = Task { [weak self] in
            let outcome = await Self.execute(id)
            self?.finish(entry, outcome: outcome, token: token)
        }
        Task { [weak self] in
            try? await Task.sleep(for: Self.spinnerTimeout)
            guard let self, tokens[id] == token, states[id] == .running else { return }
            states[id] = .idle
        }
    }

    /// Stops a run that's still going (the process is terminated).
    func stop(_ entry: ShortcutEntry) {
        tokens[entry.id] = nil
        runs.removeValue(forKey: entry.id)?.cancel()
        states[entry.id] = .idle
    }

    private nonisolated static func execute(_ id: String) async -> ShortcutRunOutcome {
        await ShortcutsCLI.run(id)
    }

    private func finish(_ entry: ShortcutEntry, outcome: ShortcutRunOutcome, token: Int) {
        let id = entry.id
        guard tokens[id] == token else { return }
        runs[id] = nil
        switch outcome {
        case .succeeded:
            states[id] = .done
            clear(id, token: token, after: .seconds(2.5))
        case .failed(let message):
            states[id] = .failed(message)
            lastFailure = Failure(id: id, name: entry.name, message: message)
            clear(id, token: token, after: .seconds(10))
        case .stopped:
            states[id] = .idle
            tokens[id] = nil
        }
    }

    /// Lets a checkmark or an error badge fade back to the plain tile.
    private func clear(_ id: String, token: Int, after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, tokens[id] == token else { return }
            tokens[id] = nil
            states[id] = .idle
            if lastFailure?.id == id { lastFailure = nil }
        }
    }

    // MARK: Pins and the Shortcuts app

    func isPinned(_ entry: ShortcutEntry) -> Bool {
        pinned.contains(entry.id)
    }

    func togglePin(_ entry: ShortcutEntry) {
        if pinned.remove(entry.id) == nil { pinned.insert(entry.id) }
        UserDefaults.standard.set(pinned.sorted(), forKey: Self.pinnedKey)
    }

    func openInShortcuts(_ entry: ShortcutEntry) {
        NSWorkspace.shared.open(ShortcutsCLI.openURL(name: entry.name))
    }

    func openShortcutsApp() {
        NSWorkspace.shared.open(ShortcutsCLI.appURL)
    }
}
