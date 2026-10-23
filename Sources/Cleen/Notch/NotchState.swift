import Foundation
import Observation

/// What the notch is doing right now. Owned by `NotchController`, read by the views.
@Observable
final class NotchState {
    var isOpen = false
    var isPinned = false
    var tab = NotchTab.home {
        didSet { if tab != oldValue { mirrorExpanded = false } }
    }
    /// The home tab's mirror grown to fill the panel.
    var mirrorExpanded = false
    /// The panel shows Ajustes instead of a tool.
    var showsSettings = false
    var settingsSection = SettingsSection.general
    var geometry: NotchGeometry?
    /// While true the panel stays open even if the pointer leaves (a confirmation is
    /// waiting, a sheet or open panel is up).
    var holdsOpen = false
}
