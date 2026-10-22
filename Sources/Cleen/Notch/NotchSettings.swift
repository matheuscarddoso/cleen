import Foundation

/// Notch preferences, read by the controller on every pointer event (cheap, and always
/// current without observation plumbing).
enum NotchSettings {
    static let openOnHoverKey = "notchOpensOnHover"
    static let hoverDelayKey = "notchHoverDelay"
    static let showsWingsKey = "notchShowsWings"

    static func register() {
        UserDefaults.standard.register(defaults: [
            openOnHoverKey: true,
            hoverDelayKey: 0.12,
            showsWingsKey: true,
        ])
    }

    static var opensOnHover: Bool { UserDefaults.standard.bool(forKey: openOnHoverKey) }
    static var hoverDelay: Double { UserDefaults.standard.double(forKey: hoverDelayKey) }
    static var showsWings: Bool { UserDefaults.standard.bool(forKey: showsWingsKey) }
}
