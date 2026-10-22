import LustroKit

/// One reading of the fast-changing metrics, taken off the main thread.
nonisolated struct SystemSnapshot: Sendable {
    let cpu: CPULoad?
    let memory: MemoryStats?
    let network: NetworkRate?
    /// Empty unless someone is looking at processes.
    let processes: [ProcessUsage]
}
