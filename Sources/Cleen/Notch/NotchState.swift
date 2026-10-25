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
    /// The small "hello" island right after the first-run tour.
    var showsWelcome = false
    /// The panel shows the launcher (⌥Space) instead of a tool.
    var showsSearch = false
    /// Opened from the keyboard: it appears and goes without animation, like a launcher.
    var opensInstantly = false
    /// Bumped once the panel holds the keyboard, so the search field takes the cursor
    /// right then (asking before the window is key does nothing).
    var searchFocusRequest = 0
    /// The panel grows tall, like a launcher: the search, and Emoji's grid.
    var isTall: Bool { isOpen && !showsWelcome && (showsSearch || (tab == .emoji && !showsSettings)) }

    /// A paste was asked for without Accessibility: the panel shows how to allow it.
    var pasteNeedsPermission = false
    var settingsSection = SettingsSection.general
    var geometry: NotchGeometry?
    /// While true the panel stays open even if the pointer leaves (a confirmation is
    /// waiting, a sheet or open panel is up).
    var holdsOpen = false
    /// The teleprompter is reading: the panel is all script, an arc of light behind it.
    var isPrompting = false
    /// Files from another app are being dragged over the open panel: the shelf swaps
    /// its tray for drop zones.
    var isDraggingFiles = false
    /// Lets the tab on screen use Esc before it closes the panel (the shelf lets go of
    /// its selection first). Returns true when it did something.
    @ObservationIgnored var escapeHandler: (() -> Bool)?
}
