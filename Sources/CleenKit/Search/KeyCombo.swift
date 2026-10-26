import Foundation

/// A global keyboard shortcut a person gave to a command: a virtual key code and the
/// Carbon modifier mask, as `RegisterEventHotKey` takes them.
public struct KeyCombo: Codable, Hashable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Carbon's modifier bits (Events.h), so this file needs no Carbon import.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    /// A shortcut needs ⌘, ⌃ or ⌥ (⇧ alone would eat capital letters), except the
    /// function keys, which are free on their own.
    public var isValid: Bool {
        modifiers & (Self.command | Self.control | Self.option) != 0 || Self.functionKeys[keyCode] != nil
    }

    /// "⌃⌥E", in the order macOS menus use.
    public var display: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "⌃" }
        if modifiers & Self.option != 0 { text += "⌥" }
        if modifiers & Self.shift != 0 { text += "⇧" }
        if modifiers & Self.command != 0 { text += "⌘" }
        return text + (Self.keyNames[keyCode] ?? Self.functionKeys[keyCode] ?? "#\(keyCode)")
    }

    /// The keys each part of `display` shows separately, for keycaps.
    public var keycaps: [String] {
        display.map(String.init).reduce(into: [String]()) { caps, character in
            // Multi-letter names ("F5", "Espaço") stay one cap.
            if let last = caps.last, !Self.modifierSymbols.contains(last), !Self.modifierSymbols.contains(character) {
                caps[caps.count - 1] += character
            } else {
                caps.append(character)
            }
        }
    }

    static let modifierSymbols: Set<String> = ["⌃", "⌥", "⇧", "⌘"]

    /// ANSI key codes (Events.h) to what's printed on the key.
    static let keyNames: [UInt32: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
        0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
        0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y", 0x06: "Z",
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9",
        0x18: "=", 0x1B: "-", 0x1E: "]", 0x21: "[", 0x27: "'", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: ".", 0x32: "`",
        0x31: "␣", 0x24: "↩", 0x30: "⇥", 0x33: "⌫", 0x35: "⎋", 0x75: "⌦",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑", 0x73: "↖", 0x77: "↘", 0x74: "⇞", 0x79: "⇟",
    ]

    static let functionKeys: [UInt32: String] = [
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12", 0x69: "F13", 0x6B: "F14", 0x71: "F15",
    ]
}
