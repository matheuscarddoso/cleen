import Foundation
import Observation

/// What the notch is doing right now. Owned by `NotchController`, read by the views.
@Observable
final class NotchState {
    var isOpen = false
    var isPinned = false
    var tab = NotchTab.home {
        didSet {
            if tab != oldValue {
                mirrorExpanded = false
                isEditingHome = false
            }
        }
    }
    /// The home tab's mirror grown to fill the panel.
    var mirrorExpanded = false
    /// Início is being rearranged: widgets go inert and show their edit controls.
    var isEditingHome = false {
        didSet { holdsOpen = isEditingHome }
    }
    /// The panel shows Ajustes instead of a tool.
    var showsSettings = false
    /// The panel shows the launcher (⌥Space) instead of a tool.
    var showsSearch = false
    /// Opened from the keyboard: it appears and goes without animation, like a launcher.
    var opensInstantly = false
    var settingsSection = SettingsSection.general
    var geometry: NotchGeometry?
    /// While true the panel stays open even if the pointer leaves (a confirmation is
    /// waiting, a sheet or open panel is up).
    var holdsOpen = false
}
