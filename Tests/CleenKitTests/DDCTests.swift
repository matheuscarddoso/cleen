import Testing
@testable import CleenKit

struct DDCTests {
    @Test func readRequestCarriesItsChecksum() {
        // 0x6E ^ 0x51 ^ 0x82 ^ 0x01 ^ 0x10
        #expect(DDC.readRequest(0x10) == [0x82, 0x01, 0x10, 0xAC])
    }

    @Test func writePacketIsBigEndianWithChecksum() {
        let packet = DDC.writePacket(0x10, value: 70)
        #expect(Array(packet.prefix(5)) == [0x84, 0x03, 0x10, 0x00, 0x46])
        #expect(packet.last == packet.dropLast().reduce(0x6E ^ 0x51) { $0 ^ $1 })
        #expect(DDC.writePacket(0x10, value: -5)[4] == 0)
    }

    @Test func parsesTheReplyAnAOCMonitorSent() throws {
        // Read from a 24G2W1G5: maximum 100, current 100.
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x64, 0xA4, 0xB5]
        let value = try #require(DDC.parseReply(reply, code: 0x10))
        #expect(value.current == 100 && value.maximum == 100)
    }

    @Test func rejectsRepliesForAnotherCodeOrGarbage() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x12, 0x00, 0x00, 0x64, 0x00, 0x32, 0x00, 0x00]
        #expect(DDC.parseReply(reply, code: 0x10) == nil)
        #expect(DDC.parseReply([UInt8](repeating: 0, count: 12), code: 0x10) == nil)
        #expect(DDC.parseReply([0x02], code: 0x10) == nil)
    }
}
