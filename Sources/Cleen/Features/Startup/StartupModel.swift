import Foundation
import CleenKit
import Observation

@Observable
final class StartupModel {
    private(set) var phase = ScanPhase.idle
    private(set) var items: [LaunchItem] = []
    private(set) var busy = Set<LaunchItem.ID>()
    private(set) var errorMessage: String?

    @ObservationIgnored private let cleanup: CleanupService

    init(cleanup: CleanupService) {
        self.cleanup = cleanup
    }

    var suspicious: [LaunchItem] { items.filter { $0.signature.isSuspicious } }

    func scan() async {
        phase = .scanning
        let found = await LaunchItemScanner().scan()
        // The rows show each app's icon; look them up before the list appears.
        await IconCache.shared.warm(found.compactMap(\.appBundle))
        items = found
        phase = .ready
    }

    func items(in scope: LaunchItem.Scope) -> [LaunchItem] {
        items.filter { $0.scope == scope }
    }

    func setEnabled(_ enabled: Bool, for item: LaunchItem) async {
        await perform(item) {
            if enabled { try await LaunchControl.enable(item) } else { try await LaunchControl.disable(item) }
        }
    }

    func remove(_ item: LaunchItem) async {
        await perform(item) { [cleanup] in
            let outcome = await LaunchControl.remove(item)
            cleanup.onChange()
            if let failure = outcome.failures.first { throw UserFacingError(failure.reason) }
        }
    }

    private func perform(_ item: LaunchItem, _ action: () async throws -> Void) async {
        busy.insert(item.id)
        defer { busy.remove(item.id) }
        errorMessage = nil
        do {
            try await action()
        } catch ShellError.cancelledByUser {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        items = await LaunchItemScanner().scan()
    }
}
