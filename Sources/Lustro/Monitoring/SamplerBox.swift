import LustroKit

/// Owns the stateful samplers (they diff against their previous reading) and runs
/// them away from the main actor.
actor SamplerBox {
    private var cpu = CPUSampler()
    private var network = NetworkSampler()
    private var processes = ProcessSampler()

    func sample(includingProcesses: Bool) -> SystemSnapshot {
        SystemSnapshot(
            cpu: cpu.sample(),
            memory: MemoryStats.read(),
            network: network.sample(),
            processes: includingProcesses ? processes.sample() : []
        )
    }
}
