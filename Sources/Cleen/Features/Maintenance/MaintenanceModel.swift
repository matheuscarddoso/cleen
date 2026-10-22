import Foundation
import CleenKit
import Observation

@Observable
final class MaintenanceModel {
    enum Outcome: Equatable {
        case success(String)
        case failure(String)
    }

    private(set) var running = Set<MaintenanceTask>()
    private(set) var outcomes: [MaintenanceTask: Outcome] = [:]
    private(set) var snapshotCount: Int?

    func refresh() async {
        snapshotCount = await MaintenanceTask.localSnapshotCount()
    }

    func run(_ task: MaintenanceTask) async {
        guard !running.contains(task) else { return }
        running.insert(task)
        outcomes[task] = nil
        defer { running.remove(task) }
        do {
            outcomes[task] = .success(try await task.run())
        } catch ShellError.cancelledByUser {
            outcomes[task] = nil
        } catch {
            outcomes[task] = .failure(error.localizedDescription)
        }
        if task == .thinSnapshots { await refresh() }
    }
}
