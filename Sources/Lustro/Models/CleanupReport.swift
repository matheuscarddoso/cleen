import LustroKit

/// What a cleanup did, kept until the next one so the result stays on screen.
struct CleanupReport: Equatable {
    let freed: Int64
    let trashed: Int64
    let failures: [RemovalFailure]

    init(_ outcome: RemovalOutcome) {
        freed = outcome.freed
        trashed = outcome.trashed
        failures = outcome.failures
    }

    init(freed: Int64, trashed: Int64 = 0, failures: [RemovalFailure] = []) {
        self.freed = freed
        self.trashed = trashed
        self.failures = failures
    }

    var headline: String {
        switch (freed > 0, trashed > 0) {
        case (true, true): "\(freed.bytes) liberados · \(trashed.bytes) no Lixo"
        case (true, false): "\(freed.bytes) liberados"
        case (false, true): "\(trashed.bytes) movidos para o Lixo"
        case (false, false): failures.isEmpty ? "Nada para remover" : "Nada foi removido"
        }
    }

    /// Failures that a password would fix.
    var permissionFailures: [RemovalFailure] { failures.filter(FileRemover.isPermissionFailure) }
}
