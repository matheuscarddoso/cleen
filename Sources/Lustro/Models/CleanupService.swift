import Foundation
import LustroKit
import Observation

/// The single path every removal goes through, so the lifetime counter, the disk
/// reading in the menu bar and the safety guard are never skipped.
@Observable
final class CleanupService {
    private let remover = FileRemover.standard
    private let defaults = UserDefaults.standard

    /// Everything Lustro has freed or trashed since it was installed.
    private(set) var lifetimeFreed: Int64

    /// Called after every removal, so free-space readings update right away.
    var onChange: () -> Void = {}

    init() {
        lifetimeFreed = Int64(UserDefaults.standard.double(forKey: "lifetimeFreed"))
    }

    func remove(_ requests: [RemovalRequest]) async -> RemovalOutcome {
        let outcome = await remover.remove(requests)
        record(outcome)
        return outcome
    }

    func removeAsAdministrator(_ requests: [RemovalRequest]) async -> RemovalOutcome {
        let outcome = await remover.removeAsAdministrator(requests)
        record(outcome)
        return outcome
    }

    /// For space released by a tool (Docker, simctl) rather than by removing files.
    func recordToolCleanup(bytes: Int64) {
        add(bytes)
        onChange()
    }

    private func record(_ outcome: RemovalOutcome) {
        add(outcome.freed + outcome.trashed)
        onChange()
    }

    private func add(_ bytes: Int64) {
        guard bytes > 0 else { return }
        lifetimeFreed += bytes
        defaults.set(Double(lifetimeFreed), forKey: "lifetimeFreed")
    }
}
