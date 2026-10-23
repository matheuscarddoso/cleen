import Foundation
import IOKit

// Apple Silicon reaches an external display's DDC/CI channel through IOAVService, which
// IOKit exports but doesn't declare (the same calls MonitorControl and m1ddc use).
@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ service: CFTypeRef, _ chip: UInt32, _ offset: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chip: UInt32, _ address: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

/// Talks to external monitors over the cable (DDC/CI), the way the monitor's own menu
/// buttons would: brightness is VCP code 0x10. Every call blocks for tens of
/// milliseconds (the monitor needs time to answer), so run them off the main thread,
/// one at a time per monitor.
public enum DDC {
    /// One external display reachable over DDC.
    public struct Port: @unchecked Sendable {
        /// The name the display reports ("24G2W1G5"), which is also `NSScreen.localizedName`.
        public let productName: String?
        let service: CFTypeRef
    }

    public static let brightness: UInt8 = 0x10

    private static let chip: UInt32 = 0x37
    private static let dataAddress: UInt32 = 0x51
    /// The host's address, folded into every checksum.
    private static let host: UInt8 = 0x6E

    /// External displays with a DDC channel, in the order IOKit lists them. Walks the
    /// whole registry (~70 ms): do it once, when the controls appear.
    public static func ports() -> [Port] {
        var iterator = io_iterator_t()
        guard IORegistryEntryCreateIterator(IORegistryGetRootEntry(kIOMainPortDefault), kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var ports: [Port] = []
        // The display's framebuffer (with its name) comes just before its AV service.
        var lastName: String?
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var buffer = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(entry, &buffer)
            let name = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if name.hasPrefix("AppleCLCD2") || name.hasPrefix("IOMobileFramebufferShim"),
               let attributes = property(entry, "DisplayAttributes") as? [String: Any],
               let product = attributes["ProductAttributes"] as? [String: Any] {
                lastName = product["ProductName"] as? String
            }
            if name == "DCPAVServiceProxy", property(entry, "Location") as? String == "External",
               let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() {
                ports.append(Port(productName: lastName, service: service))
                lastName = nil
            }
        }
        return ports
    }

    /// The control's current and maximum values, or nil when the display doesn't answer.
    public static func read(_ code: UInt8, from port: Port) -> (current: Int, maximum: Int)? {
        var request = readRequest(code)
        for _ in 0..<3 {
            let written = request.withUnsafeMutableBytes { IOAVServiceWriteI2C(port.service, chip, dataAddress, $0.baseAddress!, UInt32($0.count)) }
            usleep(40_000)
            var reply = [UInt8](repeating: 0, count: 12)
            let read = reply.withUnsafeMutableBytes { IOAVServiceReadI2C(port.service, chip, dataAddress, $0.baseAddress!, UInt32($0.count)) }
            if written == kIOReturnSuccess, read == kIOReturnSuccess, let value = parseReply(reply, code: code) { return value }
            usleep(30_000)
        }
        return nil
    }

    /// Sets a control. Monitors drop the odd message, so it's sent twice.
    @discardableResult
    public static func write(_ code: UInt8, value: Int, to port: Port) -> Bool {
        var packet = writePacket(code, value: value)
        var succeeded = false
        for _ in 0..<2 {
            let result = packet.withUnsafeMutableBytes { IOAVServiceWriteI2C(port.service, chip, dataAddress, $0.baseAddress!, UInt32($0.count)) }
            succeeded = succeeded || result == kIOReturnSuccess
            usleep(10_000)
        }
        return succeeded
    }

    // MARK: Packets

    /// "Get VCP feature": length, opcode 0x01, the code, checksum.
    static func readRequest(_ code: UInt8) -> [UInt8] {
        withChecksum([0x82, 0x01, code])
    }

    /// "Set VCP feature": length, opcode 0x03, the code, the value (big-endian), checksum.
    static func writePacket(_ code: UInt8, value: Int) -> [UInt8] {
        let clamped = UInt16(clamping: max(0, value))
        return withChecksum([0x84, 0x03, code, UInt8(clamped >> 8), UInt8(clamped & 0xFF)])
    }

    /// Finds the "VCP feature reply" in what came back: result 0x00 for our code, then
    /// type, maximum and current value, both big-endian.
    static func parseReply(_ bytes: [UInt8], code: UInt8) -> (current: Int, maximum: Int)? {
        guard bytes.count >= 8 else { return nil }
        for index in 0...(bytes.count - 8) where bytes[index] == 0x02 && bytes[index + 1] == 0x00 && bytes[index + 2] == code {
            let maximum = Int(bytes[index + 4]) << 8 | Int(bytes[index + 5])
            let current = Int(bytes[index + 6]) << 8 | Int(bytes[index + 7])
            guard maximum > 0, current <= maximum else { return nil }
            return (current, maximum)
        }
        return nil
    }

    private static func withChecksum(_ bytes: [UInt8]) -> [UInt8] {
        bytes + [bytes.reduce(host ^ UInt8(dataAddress)) { $0 ^ $1 }]
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
