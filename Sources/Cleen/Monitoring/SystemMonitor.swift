import Foundation
import CleenKit
import Observation

/// Live system readings for the menu bar and the Monitor section.
///
/// Cheap metrics tick every two seconds for as long as the app runs (the menu bar label
/// shows them). The process list — the expensive part — is only sampled while a view
/// that shows it is on screen.
@Observable
final class SystemMonitor {
    private(set) var cpu: CPULoad?
    private(set) var memory: MemoryStats?
    private(set) var disk: DiskStats?
    private(set) var battery: BatteryStats?
    private(set) var network: NetworkRate?
    private(set) var processes: [ProcessUsage] = []
    private(set) var thermalState = ProcessInfo.processInfo.thermalState

    private(set) var cpuHistory: [Double] = []
    private(set) var memoryHistory: [Double] = []
    private(set) var downloadHistory: [Double] = []
    private(set) var uploadHistory: [Double] = []

    /// Called with each disk reading; the low-space alert hangs off this.
    var onDiskReading: (DiskStats) -> Void = { _ in }

    @ObservationIgnored private let sampler = SamplerBox()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var processWatchers = 0
    @ObservationIgnored private var tick = 0

    func start() {
        guard loop == nil else { return }
        refreshDisk()
        battery = BatteryStats.read()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.step()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Keeps the process list fresh while the calling view's task is alive.
    func watchProcesses() async {
        processWatchers += 1
        defer { processWatchers -= 1 }
        await step()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
        }
    }

    func refreshDisk() {
        guard let reading = DiskStats.read() else { return }
        disk = reading
        onDiskReading(reading)
    }

    private func step() async {
        let snapshot = await sampler.sample(includingProcesses: processWatchers > 0)
        if let cpu = snapshot.cpu {
            self.cpu = cpu
            Self.append(cpu.total, to: &cpuHistory)
        }
        if let memory = snapshot.memory {
            self.memory = memory
            Self.append(memory.usedFraction, to: &memoryHistory)
        }
        if let network = snapshot.network {
            self.network = network
            Self.append(network.download, to: &downloadHistory)
            Self.append(network.upload, to: &uploadHistory)
        }
        if processWatchers > 0 {
            processes = snapshot.processes
        }

        tick += 1
        // Disk and battery move slowly; reading them every 10 s is plenty.
        if tick % 5 == 0 {
            refreshDisk()
            battery = BatteryStats.read()
            thermalState = ProcessInfo.processInfo.thermalState
        }
    }

    private static func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > Sparkline.capacity { history.removeFirst(history.count - Sparkline.capacity) }
    }
}
