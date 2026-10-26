import AppKit

/// Where the notch is on a screen and how big the panel grows from it.
struct NotchGeometry: Equatable {
    /// The screen's full frame, in global (bottom-left origin) coordinates.
    let screenFrame: CGRect
    /// The camera housing, or a drawn stand-in on screens without one.
    let notchSize: CGSize
    let hasPhysicalNotch: Bool

    /// Width each live-activity wing adds beside the notch when it's closed.
    static let wingWidth = 46.0
    /// One size for every tool, so switching tabs never resizes the panel. Wider and
    /// taller are a choice in Aparência.
    static var openPanelSize: CGSize { NotchSettings.panelSize }
    /// Room around the open panel for its shadow; the window is this much larger.
    static let shadowPadding = 36.0
    /// The launcher grows the panel this tall, so a page of results fits (Raycast's
    /// window shows about eight rows; this shows about as many).
    static let searchHeight = 404.0

    init(screen: NSScreen) {
        screenFrame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // A point wider and taller than the housing: drawn exactly to its edge, the
            // antialiased rim fell short and the closed notch looked a pixel small.
            notchSize = CGSize(width: screen.frame.width - left.width - right.width + 2, height: screen.safeAreaInsets.top + 1)
            hasPhysicalNotch = true
        } else {
            // No camera housing: draw a compact island the height of the menu bar.
            let menuBar = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            notchSize = CGSize(width: 180, height: menuBar)
            hasPhysicalNotch = false
        }
    }

    func closedSize(showsWings: Bool) -> CGSize {
        closedSize(wingWidth: showsWings ? Self.wingWidth : 0)
    }

    func closedSize(wingWidth: Double) -> CGSize {
        CGSize(width: notchSize.width + wingWidth * 2, height: notchSize.height)
    }

    var openSize: CGSize { openSize(.standard) }

    /// How tall the open panel is right now.
    enum PanelHeight: Equatable {
        /// Every tool's size, as chosen in Aparência.
        case standard
        /// The launcher, Emoji, Ajustes and a review: a page of rows fits.
        case tall
        /// The wide mirror: the camera's whole 16:9 picture, nothing cropped.
        case mirror
    }

    func openSize(_ height: PanelHeight) -> CGSize {
        let width = min(Self.openPanelSize.width, screenFrame.width - 40)
        let standard = Self.openPanelSize.height
        switch height {
        case .standard:
            return CGSize(width: width, height: standard)
        case .tall:
            return CGSize(width: width, height: max(standard, min(Self.searchHeight, screenFrame.height * 0.6)))
        case .mirror:
            // The camera strip, the 6 pt above the tool, the picture at 16:9 across the
            // content width, and the inset below it (the tab bar steps aside).
            let content = width - 2 * (NotchStyle.openTopRadius + NotchOpenContent.inset)
            let picture = content * 9 / 16
            return CGSize(width: width, height: max(standard, min(notchSize.height + 6 + picture + NotchOpenContent.inset, screenFrame.height * 0.75)))
        }
    }

    /// The greeting after the tour: a small island under the camera, NotchNook's "hello".
    var welcomeSize: CGSize {
        CGSize(width: max(notchSize.width + 150, 330), height: notchSize.height + 141)
    }

    /// The panel window: room for the tallest the panel gets (the wide mirror,
    /// Emoji, the launcher, a review) plus its shadow, hanging from the top. It never changes size while the
    /// panel animates: resizing it mid-animation made the whole panel drop and crawl back
    /// up. The clear part costs nothing: closed, the window lets every click through, and
    /// open, a click there closes the panel like any click outside it.
    var windowFrame: CGRect {
        let size = CGSize(width: openSize(.tall).width, height: max(openSize(.tall).height, openSize(.mirror).height))
        let width = size.width + Self.shadowPadding * 2
        let height = size.height + Self.shadowPadding
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// The area that reacts to the pointer, in global coordinates.
    func hotZone(isOpen: Bool, showsWings: Bool, height: PanelHeight = .standard) -> CGRect {
        let size = isOpen ? openSize(height) : closedSize(showsWings: showsWings)
        let rect = CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
        // A little forgiveness: the closed notch is small, the open edge shouldn't be a cliff.
        return isOpen ? rect.insetBy(dx: -14, dy: -14) : rect.insetBy(dx: -6, dy: -3)
    }
}
