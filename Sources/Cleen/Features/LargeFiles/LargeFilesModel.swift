import Foundation
import CleenKit
import Observation

@Observable
final class LargeFilesModel {
    static let minimumKey = "largeFileMinimumMB"

    private(set) var phase = ScanPhase.idle
    private(set) var progress = ""
    private(set) var files: [FoundFile] = []
    private(set) var isCleaning = false
    private(set) var report: CleanupReport?

    var selection = Set<URL>()
    var kind: FileKind?
    var sort = FileSort.size

    @ObservationIgnored private let cleanup: CleanupService
    @ObservationIgnored private var task: Task<Void, Never>?

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
        UserDefaults.standard.register(defaults: [Self.minimumKey: 50])
    }

    var minimumMB: Int { UserDefaults.standard.integer(forKey: Self.minimumKey) }

    /// Files after the kind filter and sort, recomputed only when inputs change.
    var visibleFiles: [FoundFile] {
        let filtered = kind.map { kind in files.filter { $0.kind == kind } } ?? files
        return switch sort {
        case .size: filtered
        case .oldest: filtered.sorted { $0.lastUsed < $1.lastUsed }
        }
    }

    var kindsPresent: [FileKind] {
        let present = Set(files.map(\.kind))
        return FileKind.allCases.filter(present.contains)
    }

    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { files.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { files.count { selection.contains($0.url) } }

    func startScan() {
        task?.cancel()
        task = Task { await performScan() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = files.isEmpty ? .idle : .ready
    }

    private func performScan() async {
        phase = .scanning
        report = nil
        let scanner = LargeFileScanner(minimumSize: Int64(minimumMB) * 1_000_000)
        let found = await offMain {
            scanner.scan { path in
                Task { @MainActor [weak self] in self?.progress = Paths.abbreviate(URL(filePath: path)) }
            }
        }
        guard !Task.isCancelled else { return }
        files = found
        // Nothing starts selected: these are the person's own files.
        selection = []
        kind = nil
        phase = .ready
    }

    func toggle(_ file: FoundFile) {
        if selection.contains(file.url) { selection.remove(file.url) } else { selection.insert(file.url) }
    }

    func moveToTrash() async {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }
        let outcome = await cleanup.remove(files.filter { selection.contains($0.url) }.map(\.request))
        let removed = Set(outcome.removed)
        files.removeAll { removed.contains($0.url) }
        selection.subtract(removed)
        report = CleanupReport(outcome)
    }
}
