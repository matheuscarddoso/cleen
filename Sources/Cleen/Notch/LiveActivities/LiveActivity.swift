import AppKit

/// Something worth a glance on the closed notch. Banners widen the wings for a few
/// seconds and go; a meeting about to start stays, compact, until it begins.
enum LiveActivity: Hashable {
    case power(Power, level: Double)
    case headphones(name: String, connected: Bool)
    case track(title: String, artist: String)
    case meeting(title: String, start: Date, color: NSColor)
    /// A timer or Pomodoro phase that just ran out ("Foco", "Pausa", "Timer").
    case timerEnded(phase: String)
    /// Something went to the clipboard from the search (a picked color, a result).
    case copied(text: String, color: NSColor?)
    /// The result of a command run from the search with the notch already closed
    /// ("Discos" · "2 ejetados").
    case notice(title: String, detail: String, symbol: String)
    /// A download that just finished: the notch grows into an island with the file.
    case downloaded(url: URL, size: Int64)

    enum Power: Hashable {
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

    /// The finished-download island: wider than the wings, and taller than the notch.
    var isIsland: Bool {
        if case .downloaded = self { return true }
        return false
    }

    static let islandWingWidth = 130.0
    static let islandExtraHeight = 62.0
}
