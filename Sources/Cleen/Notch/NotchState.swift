import Foundation
import Observation
import SwiftUI

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
    /// The panel grows tall, like a launcher: the search, Emoji's grid, Ajustes, and the
    /// review of something about to be deleted.
    var isTall: Bool { isOpen && !showsWelcome && (showsSearch || showsSettings || deletionReview != nil || tab == .emoji) }

    /// The tabs' dock floats under the open panel, except where a tool takes the whole
    /// panel (the wide mirror, Início's edit mode, the teleprompter reading) and over the
    /// launcher, Ajustes, the welcome and a review.
    var showsTabDock: Bool {
        guard isOpen, !showsWelcome, !showsSearch, !showsSettings, deletionReview == nil else { return false }
        if tab == .home, mirrorExpanded || isEditingHome { return false }
        if tab == .teleprompter, isPrompting { return false }
        return true
    }

    /// The open panel's height: tall for the above, taller still for the wide mirror so
    /// the whole camera picture shows.
    var panelHeight: NotchGeometry.PanelHeight {
        if isTall { return .tall }
        if isOpen, !showsWelcome, tab == .home, mirrorExpanded { return .mirror }
        if isOpen, !showsWelcome, !showsSettings, !showsSearch, isCompactTool { return .compact }
        return .standard
    }

    /// Something is about to be deleted: the panel lists it and waits for Confirmar.
    private(set) var deletionReview: DeletionReview?
    /// Whether the panel was held open before the review took over.
    @ObservationIgnored private var heldBeforeReview = false

    /// Grows the panel into the review; nothing is deleted until it's confirmed.
    func review(_ review: DeletionReview) {
        if deletionReview == nil { heldBeforeReview = holdsOpen }
        holdsOpen = true
        withAnimation(NotchController.searchResize) { deletionReview = review }
    }

    func confirmDeletion() {
        guard let review = deletionReview else { return }
        endReview()
        review.confirm()
    }

    func cancelDeletion() {
        guard deletionReview != nil else { return }
        endReview()
    }

    private func endReview() {
        holdsOpen = heldBeforeReview
        withAnimation(NotchController.searchResize) { deletionReview = nil }
    }

    /// A paste was asked for without Accessibility: the panel shows how to allow it.
    var pasteNeedsPermission = false
    var settingsSection = SettingsSection.general
    var geometry: NotchGeometry?
    /// While true the panel stays open even if the pointer leaves (a confirmation is
    /// waiting, a sheet or open panel is up).
    var holdsOpen = false
    /// The tool on screen is a single bar (Gravar with nothing else to show): the panel
    /// shrinks around it.
    var isCompactTool = false
    /// The teleprompter is reading: the panel is all script, an arc of light behind it.
    var isPrompting = false
    /// Files from another app are being dragged over the open panel: the shelf swaps
    /// its tray for drop zones.
    var isDraggingFiles = false
    /// Lets the tab on screen use Esc before it closes the panel (the shelf lets go of
    /// its selection first). Returns true when it did something.
    @ObservationIgnored var escapeHandler: (() -> Bool)?
}
