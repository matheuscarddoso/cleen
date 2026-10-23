import CoreGraphics

/// Dims a display by scaling its gamma table, for monitors that don't take brightness
/// over the cable. The display's own table (its ColorSync calibration) is kept and
/// scaled, so colors stay right; full brightness puts it back exactly.
enum ScreenDimming {
    private static var originals: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]

    /// The dimmest it goes: below this the screen reads as off.
    static let minimum = 0.25

    static func apply(_ level: Double, to display: CGDirectDisplayID) {
        let level = min(1, max(minimum, level))
        if originals[display] == nil, let table = readTable(display) { originals[display] = table }
        guard let original = originals[display] else { return }
        let scale = CGGammaValue(level)
        let red = original.red.map { $0 * scale }
        let green = original.green.map { $0 * scale }
        let blue = original.blue.map { $0 * scale }
        CGSetDisplayTransferByTable(display, UInt32(red.count), red, green, blue)
        if level >= 1 { originals[display] = nil }
    }

    private static func readTable(_ display: CGDirectDisplayID) -> (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])? {
        let capacity = Int(CGDisplayGammaTableCapacity(display))
        guard capacity > 0 else { return nil }
        var red = [CGGammaValue](repeating: 0, count: capacity)
        var green = [CGGammaValue](repeating: 0, count: capacity)
        var blue = [CGGammaValue](repeating: 0, count: capacity)
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, UInt32(capacity), &red, &green, &blue, &count) == .success, count > 0 else { return nil }
        let used = Int(count)
        return (Array(red.prefix(used)), Array(green.prefix(used)), Array(blue.prefix(used)))
    }
}
