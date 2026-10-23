import Foundation

/// The volume and brightness keys, as macOS reports them: a system-defined event
/// (NX_SYSDEFINED, subtype 8, "aux control button") whose `data1` packs the key code in
/// the high 16 bits, the key state in the next byte and a repeat flag in the lowest bit.
public enum MediaKey: Sendable, Equatable, CaseIterable {
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown

    /// `NX_SYSDEFINED`, the CGEvent type these keys arrive as.
    public static let systemDefinedEventType: UInt32 = 14
    /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`.
    public static let auxControlSubtype = 8

    /// One press, release or auto-repeat of a media key.
    public struct Press: Sendable, Equatable {
        public let key: MediaKey
        public let isDown: Bool
        public let isRepeat: Bool

        public init(key: MediaKey, isDown: Bool, isRepeat: Bool) {
            self.key = key
            self.isDown = isDown
            self.isRepeat = isRepeat
        }
    }

    /// `NX_KEYTYPE_*` from `IOKit/hidsystem/ev_keymap.h`.
    public var code: Int {
        switch self {
        case .volumeUp: 0
        case .volumeDown: 1
        case .brightnessUp: 2
        case .brightnessDown: 3
        case .mute: 7
        }
    }

    public var isVolume: Bool { self == .volumeUp || self == .volumeDown || self == .mute }

    /// The key behind a system-defined event, or nil for anything else (play/pause,
    /// keyboard backlight, other subtypes).
    public static func decode(subtype: Int, data1: Int) -> Press? {
        guard subtype == auxControlSubtype else { return nil }
        let code = (data1 & 0xFFFF_0000) >> 16
        guard let key = allCases.first(where: { $0.code == code }) else { return nil }
        let flags = data1 & 0xFFFF
        let state = (flags & 0xFF00) >> 8
        // 0x0A key down, 0x0B key up.
        guard state == 0x0A || state == 0x0B else { return nil }
        return Press(key: key, isDown: state == 0x0A, isRepeat: flags & 0x1 == 1)
    }

    /// The `data1` a press carries; the inverse of `decode`, for tests.
    public static func data1(for press: Press) -> Int {
        press.key.code << 16 | (press.isDown ? 0x0A : 0x0B) << 8 | (press.isRepeat ? 1 : 0)
    }
}

/// How far one press moves a level: sixteen steps like the system's own, or a quarter
/// of one with ⌥⇧ held. Levels snap to that grid, so a level set by a slider lands back
/// on a step after one press, the way macOS does it.
public enum LevelStep {
    public static let standard = 1.0 / 16
    public static let fine = 1.0 / 64

    public static func next(_ level: Double, up: Bool, fine: Bool) -> Double {
        let step = fine ? Self.fine : standard
        let position = min(1, max(0, level)) / step
        // Tolerance for levels that come back from the device a hair off the grid.
        let snapped = up ? (position + 1e-4).rounded(.down) + 1 : (position - 1e-4).rounded(.up) - 1
        return min(1, max(0, snapped * step))
    }

    /// 0...1 as a whole percentage, the way the HUD shows it.
    public static func percent(_ level: Double) -> Int {
        Int((min(1, max(0, level)) * 100).rounded())
    }
}

/// What a volume key does to the output's state.
public struct VolumeState: Sendable, Equatable {
    public var level: Double
    public var isMuted: Bool

    public init(level: Double, isMuted: Bool) {
        self.level = level
        self.isMuted = isMuted
    }

    /// Up unmutes and raises, down lowers (and stays muted if it was), mute toggles.
    public func applying(_ key: MediaKey, fine: Bool) -> VolumeState {
        switch key {
        case .mute:
            return VolumeState(level: level, isMuted: !isMuted)
        case .volumeUp:
            return VolumeState(level: LevelStep.next(level, up: true, fine: fine), isMuted: false)
        case .volumeDown:
            return VolumeState(level: LevelStep.next(level, up: false, fine: fine), isMuted: isMuted)
        case .brightnessUp, .brightnessDown:
            return self
        }
    }

    /// Silent either way: muted, or turned all the way down.
    public var isSilent: Bool { isMuted || level <= 0.0001 }
}
