import Darwin
import Foundation

public struct NetworkRate: Sendable, Equatable {
    /// Bytes per second.
    public let download: Double
    public let upload: Double
}

/// Network throughput from the kernel's 64-bit interface counters.
/// (`getifaddrs` exposes 32-bit counters that wrap every 4 GB.)
public struct NetworkSampler {
    private var previous: (received: UInt64, sent: UInt64, time: ContinuousClock.Instant)?

    public init() {}

    /// The first call primes the counters and returns nil.
    public mutating func sample() -> NetworkRate? {
        guard let totals = Self.totals() else { return nil }
        let now = ContinuousClock.now
        defer { previous = (totals.received, totals.sent, now) }
        guard let previous else { return nil }

        let elapsed = (now - previous.time) / .seconds(1)
        guard elapsed > 0 else { return nil }
        // A counter reset (interface gone) shows as going backwards; report zero, not garbage.
        let received = totals.received >= previous.received ? totals.received - previous.received : 0
        let sent = totals.sent >= previous.sent ? totals.sent - previous.sent : 0
        return NetworkRate(download: Double(received) / elapsed, upload: Double(sent) / elapsed)
    }

    static func totals() -> (received: UInt64, sent: UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if info.ifm_flags & IFF_LOOPBACK == 0 {
                        received += info.ifm_data.ifi_ibytes
                        sent += info.ifm_data.ifi_obytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return (received, sent)
    }
}
