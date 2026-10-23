import AppKit

/// Something worth a glance on the closed notch. Banners widen the wings for a few
/// seconds and go; a meeting about to start stays, compact, until it begins.
enum LiveActivity: Equatable {
    case power(Power, level: Double)
    case headphones(name: String, connected: Bool)
    case track(title: String, artist: String)
    case meeting(title: String, start: Date, color: NSColor)
    /// A timer or Pomodoro phase that just ran out ("Foco", "Pausa", "Timer").
    case timerEnded(phase: String)
    /// A Claude Code session finished its turn and is waiting.
    case agentFinished(title: String)

    enum Power: Equatable {
        case charging
        case unplugged
        case full
        case low
    }

    /// Banners get room for a word or two on each side of the camera.
    var isBanner: Bool {
        if case .meeting = self { return false }
        return true
    }

    static let bannerWingWidth = 112.0
}
