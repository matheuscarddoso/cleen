import CleenKit

/// Runs blocking file-system work off the main actor *and* off Swift's cooperative pool
/// (see `BlockingIO` for why the pool matters).
nonisolated func offMain<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
    await BlockingIO.run(work)
}
