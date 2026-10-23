import Foundation
import CoreGraphics

/// Notch preferences, read by the controller on every pointer event (cheap, and always
/// current without observation plumbing).
enum NotchSettings {
    static let openOnHoverKey = "notchOpensOnHover"
    static let hoverDelayKey = "notchHoverDelay"
    static let showsWingsKey = "notchShowsWings"
    static let allScreensKey = "notchOnAllScreens"
    static let gesturesKey = "notchAllowsGestures"
    static let panelWidthKey = "notchPanelWidth"
    static let panelHeightKey = "notchPanelHeight"

    static let widths: [(label: String, value: Double)] = [("Padrão", 680), ("Largo", 780), ("Extra", 880)]
    static let heights: [(label: String, value: Double)] = [("Padrão", 234), ("Alto", 274), ("Mais alto", 314)]

    static func register() {
        UserDefaults.standard.register(defaults: [
            openOnHoverKey: true,
            hoverDelayKey: 0.12,
            showsWingsKey: true,
            allScreensKey: false,
            gesturesKey: true,
            panelWidthKey: 680.0,
            panelHeightKey: 234.0,
        ])
    }

    static var opensOnHover: Bool { UserDefaults.standard.bool(forKey: openOnHoverKey) }
    static var hoverDelay: Double { UserDefaults.standard.double(forKey: hoverDelayKey) }
    static var showsWings: Bool { UserDefaults.standard.bool(forKey: showsWingsKey) }
    static var showsOnAllScreens: Bool { UserDefaults.standard.bool(forKey: allScreensKey) }
    static var allowsGestures: Bool { UserDefaults.standard.bool(forKey: gesturesKey) }
    /// The open panel, as chosen in Aparência; never smaller than the original.
    static var panelSize: CGSize {
        CGSize(
            width: max(680, UserDefaults.standard.double(forKey: panelWidthKey)),
            height: max(234, UserDefaults.standard.double(forKey: panelHeightKey))
        )
    }
}
