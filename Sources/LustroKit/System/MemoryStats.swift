import Darwin
import Foundation

public struct MemoryStats: Sendable, Equatable {
    public enum Pressure: Sendable, Equatable {
        case normal
        case warning
        case critical
    }

    public let total: Int64
    /// Memory apps are actively holding: app + wired + compressed, as Activity Monitor counts it.
    public let used: Int64
    public let app: Int64
    public let wired: Int64
    public let compressed: Int64
    /// File cache macOS hands back the moment anyone needs it.
    public let cached: Int64
    public let swapUsed: Int64
    public let pressure: Pressure

    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    public static func read() -> MemoryStats? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }

        let page = Int64(getpagesize())
        let app = (Int64(stats.internal_page_count) - Int64(stats.purgeable_count)) * page
        let wired = Int64(stats.wire_count) * page
        let compressed = Int64(stats.compressor_page_count) * page
        let cached = (Int64(stats.external_page_count) + Int64(stats.purgeable_count)) * page

        return MemoryStats(
            total: Int64(ProcessInfo.processInfo.physicalMemory),
            used: app + wired + compressed,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            swapUsed: swapUsed(),
            pressure: pressure()
        )
    }

    static func pressure() -> Pressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        return switch level {
        case 4: .critical
        case 2: .warning
        default: .normal
        }
    }

    static func swapUsed() -> Int64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return Int64(usage.xsu_used)
    }
}
