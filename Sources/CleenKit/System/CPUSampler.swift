import Darwin

public struct CPULoad: Sendable, Equatable {
    public let user: Double
    public let system: Double

    /// 0...1 across all cores.
    public var total: Double { min(1, user + system) }
}

/// Measures CPU use as the change in kernel tick counters between two calls.
public struct CPUSampler {
    private let host = mach_host_self()
    private var previous: [UInt32] = []

    public init() {}

    /// The first call primes the counters and returns nil.
    public mutating func sample() -> CPULoad? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info
        else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let ticks = (0..<Int(infoCount)).map { UInt32(bitPattern: info[$0]) }
        defer { previous = ticks }
        guard previous.count == ticks.count else { return nil }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        let stride = Int(CPU_STATE_MAX)
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * stride
            // Counters are 32-bit and wrap; wrapping subtraction keeps the delta right.
            func delta(_ state: Int32) -> UInt64 {
                UInt64(ticks[base + Int(state)] &- previous[base + Int(state)])
            }
            user += delta(CPU_STATE_USER) + delta(CPU_STATE_NICE)
            system += delta(CPU_STATE_SYSTEM)
            idle += delta(CPU_STATE_IDLE)
        }
        let total = Double(user + system + idle)
        guard total > 0 else { return CPULoad(user: 0, system: 0) }
        return CPULoad(user: Double(user) / total, system: Double(system) / total)
    }
}
