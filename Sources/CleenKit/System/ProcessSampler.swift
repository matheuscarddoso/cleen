import Darwin
import Foundation

/// Per-process CPU and memory for the current user's processes. Processes owned by
/// other users (root daemons) aren't readable without privileges and are skipped.
public struct ProcessSampler {
    private var previousCPU: [Int32: UInt64] = [:]
    private var previousTime: UInt64 = 0
    private var names: [Int32: (name: String, app: URL?)] = [:]
    private let timebase: (numer: UInt64, denom: UInt64)

    public init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebase = (UInt64(info.numer), UInt64(max(info.denom, 1)))
    }

    /// CPU is 0 on the first call, since it needs two readings.
    public mutating func sample() -> [ProcessUsage] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count) + 32)
        let filled = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<Int32>.size))
        }
        guard filled > 0 else { return [] }

        let now = nanoseconds(mach_absolute_time())
        let wall = previousTime > 0 ? now - previousTime : 0
        var currentCPU: [Int32: UInt64] = [:]
        var usages: [ProcessUsage] = []

        for pid in pids.prefix(Int(filled)) where pid > 0 {
            var info = rusage_info_v4()
            let status = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard status == 0 else { continue }

            // rusage times are in Mach ticks on Apple silicon, nanoseconds on Intel;
            // the timebase converts both.
            let cpuTime = nanoseconds(info.ri_user_time + info.ri_system_time)
            currentCPU[pid] = cpuTime
            var percent = 0.0
            if wall > 0, let before = previousCPU[pid], cpuTime >= before {
                percent = Double(cpuTime - before) / Double(wall) * 100
            }

            let identity = names[pid] ?? Self.identify(pid)
            names[pid] = identity
            usages.append(ProcessUsage(
                pid: pid,
                name: identity.name,
                appURL: identity.app,
                cpu: percent,
                memory: Int64(info.ri_phys_footprint)
            ))
        }

        previousCPU = currentCPU
        previousTime = now
        names = names.filter { currentCPU[$0.key] != nil }
        return usages
    }

    private func nanoseconds(_ ticks: UInt64) -> UInt64 {
        ticks.multipliedReportingOverflow(by: timebase.numer).overflow
            ? ticks / timebase.denom * timebase.numer
            : ticks * timebase.numer / timebase.denom
    }

    static func identify(_ pid: Int32) -> (name: String, app: URL?) {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else {
            var name = [CChar](repeating: 0, count: 64)
            proc_name(pid, &name, UInt32(name.count))
            return (Self.string(from: name), nil)
        }
        let path = Self.string(from: buffer)
        let url = URL(filePath: path)
        // `/Applications/Slack.app/Contents/MacOS/Slack` → the outermost .app.
        let components = url.pathComponents
        if let index = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let app = URL(filePath: NSString.path(withComponents: Array(components[...index])))
            let isMainExecutable = index + 3 == components.count - 1
            let appName = String(components[index].dropLast(4))
            return (isMainExecutable ? appName : "\(appName) · \(url.lastPathComponent)", app)
        }
        return (readableName(for: url), nil)
    }

    /// Tools installed as `…/claude/versions/2.1.308` run under a version number;
    /// walk up past version-like and generic folders to the tool's real name.
    static func readableName(for executable: URL) -> String {
        let generic: Set<String> = ["bin", "versions", "current", "libexec", "sbin", "MacOS"]
        var components = executable.pathComponents
        while let last = components.last, components.count > 1,
              last.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) || generic.contains(last) {
            components.removeLast()
        }
        return components.last ?? executable.lastPathComponent
    }

    private static func string(from buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
