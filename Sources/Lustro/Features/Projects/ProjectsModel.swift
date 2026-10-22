import Foundation
import LustroKit
import Observation

@Observable
final class ProjectsModel {
    static let staleDaysKey = "projectStaleDays"
    static let extraRootsKey = "projectExtraRoots"

    private(set) var phase = ScanPhase.idle
    private(set) var progress = ""
    private(set) var projects: [CodeProject] = []
    private(set) var isCleaning = false
    private(set) var report: CleanupReport?
    private(set) var roots: [URL] = []

    var selection = Set<URL>()

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults.standard

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
        defaults.register(defaults: [Self.staleDaysKey: 30])
        roots = Self.resolveRoots(extra: defaults.stringArray(forKey: Self.extraRootsKey) ?? [])
    }

    var staleDays: Int { defaults.integer(forKey: Self.staleDaysKey) }
    var staleThreshold: TimeInterval { TimeInterval(staleDays) * 86_400 }

    var totalSize: Int64 { projects.reduce(0) { $0 + $1.totalSize } }

    var staleSize: Int64 {
        projects.filter { $0.isStale(threshold: staleThreshold) }.reduce(0) { $0 + $1.totalSize }
    }

    private var allArtifacts: [ProjectArtifact] { projects.flatMap(\.artifacts) }

    var selectedSize: Int64 { allArtifacts.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { allArtifacts.count { selection.contains($0.url) } }

    // MARK: Roots

    func addRoot(_ url: URL) {
        var extra = defaults.stringArray(forKey: Self.extraRootsKey) ?? []
        let path = url.path(percentEncoded: false)
        guard !extra.contains(path) else { return }
        extra.append(path)
        defaults.set(extra, forKey: Self.extraRootsKey)
        roots = Self.resolveRoots(extra: extra)
    }

    func removeRoot(_ url: URL) {
        let path = url.path(percentEncoded: false)
        let extra = (defaults.stringArray(forKey: Self.extraRootsKey) ?? []).filter { $0 != path }
        defaults.set(extra, forKey: Self.extraRootsKey)
        roots = Self.resolveRoots(extra: extra)
    }

    func isCustomRoot(_ url: URL) -> Bool {
        (defaults.stringArray(forKey: Self.extraRootsKey) ?? []).contains(url.path(percentEncoded: false))
    }

    private static func resolveRoots(extra: [String]) -> [URL] {
        let custom = extra.map { URL(filePath: $0, directoryHint: .isDirectory) }
        var seen = Set<String>()
        return (ProjectScanner.defaultRoots() + custom).filter { seen.insert($0.path(percentEncoded: false)).inserted }
    }

    // MARK: Scanning

    func scan() async {
        task?.cancel()
        let task = Task { await performScan() }
        self.task = task
        await task.value
    }

    func startScan() {
        task?.cancel()
        task = Task { await performScan() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = projects.isEmpty ? .idle : .ready
    }

    private func performScan() async {
        phase = .scanning
        report = nil
        let scanner = ProjectScanner(roots: roots)
        let found = await scanner.scan { path in
            Task { @MainActor [weak self] in self?.progress = Paths.abbreviate(URL(filePath: path)) }
        }
        guard !Task.isCancelled else { return }
        projects = found
        let threshold = staleThreshold
        selection = Set(found.filter { $0.isStale(threshold: threshold) }
            .flatMap(\.artifacts)
            .filter(\.kind.selectedWhenStale)
            .map(\.url))
        phase = .ready
    }

    // MARK: Selection

    func state(of project: CodeProject) -> CheckState {
        CheckState(selected: project.artifacts.count { selection.contains($0.url) }, of: project.artifacts.count)
    }

    func toggle(_ project: CodeProject) {
        let urls = project.artifacts.map(\.url)
        if state(of: project) == .on { selection.subtract(urls) } else { selection.formUnion(urls) }
    }

    func toggle(_ artifact: ProjectArtifact) {
        if selection.contains(artifact.url) { selection.remove(artifact.url) } else { selection.insert(artifact.url) }
    }

    func selectStale() {
        let threshold = staleThreshold
        selection = Set(projects.filter { $0.isStale(threshold: threshold) }.flatMap(\.artifacts).filter(\.kind.selectedWhenStale).map(\.url))
    }

    func selectNone() {
        selection.removeAll()
    }

    // MARK: Cleaning

    func clean() async {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        let requests = allArtifacts.filter { selection.contains($0.url) }.map(\.request)
        let outcome = await cleanup.remove(requests)
        let removed = Set(outcome.removed)
        projects = projects.compactMap { project in
            let remaining = project.artifacts.filter { !removed.contains($0.url) }
            guard !remaining.isEmpty else { return nil }
            return CodeProject(url: project.url, name: project.name, lastActivity: project.lastActivity, artifacts: remaining)
        }
        selection.subtract(removed)
        report = CleanupReport(outcome)
    }
}
