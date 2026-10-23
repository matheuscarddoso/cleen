import Foundation

/// Which live activities the closed notch shows, and what it shows when nothing is
/// going on. Read on demand, like `NotchSettings`.
enum LiveActivitySettings {
    static let powerKey = "liveActivityPower"
    static let headphonesKey = "liveActivityHeadphones"
    static let trackKey = "liveActivityTrack"
    static let meetingKey = "liveActivityMeeting"
    static let agentsKey = "liveActivityAgents"
    static let idleKey = "notchIdleIndicator"
    static let hideInFullscreenKey = "notchHidesInFullscreen"

    /// What sits beside the camera when nothing is playing or happening.
    enum Idle: String, CaseIterable {
        case disk
        case battery
        case cpu
        case none

        var label: String {
            switch self {
            case .disk: String(localized: "Disco")
            case .battery: String(localized: "Bateria")
            case .cpu: "CPU"
            case .none: String(localized: "Nada")
            }
        }
    }

    static func register() {
        UserDefaults.standard.register(defaults: [
            powerKey: true,
            headphonesKey: true,
            trackKey: true,
            meetingKey: true,
            agentsKey: true,
            idleKey: Idle.disk.rawValue,
            hideInFullscreenKey: true,
        ])
    }

    static var power: Bool { UserDefaults.standard.bool(forKey: powerKey) }
    static var headphones: Bool { UserDefaults.standard.bool(forKey: headphonesKey) }
    static var track: Bool { UserDefaults.standard.bool(forKey: trackKey) }
    static var meeting: Bool { UserDefaults.standard.bool(forKey: meetingKey) }
    static var agents: Bool { UserDefaults.standard.bool(forKey: agentsKey) }
    static var hidesInFullscreen: Bool { UserDefaults.standard.bool(forKey: hideInFullscreenKey) }
}
