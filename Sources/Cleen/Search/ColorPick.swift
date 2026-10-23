import AppKit

/// The system's color sampler (the magnifier from Digital Color Meter): the picked
/// color goes to the clipboard as hex, and the last few are kept for the search.
enum ColorPick {
    private static let historyKey = "searchPickedColors"
    private static var sampler: NSColorSampler?

    static var recent: [String] { UserDefaults.standard.stringArray(forKey: historyKey) ?? [] }

    static func pick(then done: @escaping @MainActor (String) -> Void) {
        let sampler = NSColorSampler()
        self.sampler = sampler
        sampler.show { color in
            let picked = color.flatMap { Self.hex($0) }
            Task { @MainActor in
                Self.sampler = nil
                guard let picked else { return }
                copy(picked)
                var history = recent.filter { $0 != picked }
                history.insert(picked, at: 0)
                UserDefaults.standard.set(Array(history.prefix(12)), forKey: historyKey)
                done(picked)
            }
        }
    }

    static func copy(_ hex: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    nonisolated static func hex(_ color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        let channels = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 255).rounded()).clamped(to: 0...255) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }

    static func color(hex: String) -> NSColor? {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

private extension Int {
    nonisolated func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(range.upperBound, Swift.max(range.lowerBound, self)) }
}
