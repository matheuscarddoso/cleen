/// Runs blocking file-system work on the concurrent pool instead of the main actor.
/// The scanners are synchronous on purpose (they're plain loops over `fts`); this is
/// the single place that moves them off the UI thread.
@concurrent
nonisolated func offMain<T: Sendable>(_ work: @Sendable () -> T) async -> T {
    work()
}
