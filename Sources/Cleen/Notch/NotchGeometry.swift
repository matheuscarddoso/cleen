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

    var openSize: CGSize { openSize(showsSearch: false) }

    /// The open panel; taller while it shows the launcher, never shorter than the
    /// size chosen in Aparência.
    func openSize(showsSearch: Bool) -> CGSize {
        CGSize(
            width: min(Self.openPanelSize.width, screenFrame.width - 40),
            height: showsSearch ? max(Self.openPanelSize.height, min(Self.searchHeight, screenFrame.height * 0.6)) : Self.openPanelSize.height
        )
    }

    /// Room around the panel for the teleprompter's glow, which spills out below it and
    /// beside it.
    static let glowRoom = CGSize(width: 190, height: 240)

    /// The greeting after the tour: a small island under the camera, NotchNook's "hello".
    var welcomeSize: CGSize {
        CGSize(width: max(notchSize.width + 150, 330), height: notchSize.height + 141)
    }

    /// The panel window: as big as the open notch plus shadow, hanging from the top.
    /// It grows for the launcher and shrinks back after, so the clear area under a
    /// normal panel never sits over the app below.
    func windowFrame(showsSearch: Bool, glows: Bool = false) -> CGRect {
        let size = openSize(showsSearch: showsSearch)
        let room = glows ? Self.glowRoom : CGSize(width: Self.shadowPadding, height: Self.shadowPadding)
        let width = size.width + room.width * 2
        let height = size.height + room.height
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// The area that reacts to the pointer, in global coordinates.
    func hotZone(isOpen: Bool, showsWings: Bool, showsSearch: Bool = false) -> CGRect {
        let size = isOpen ? openSize(showsSearch: showsSearch) : closedSize(showsWings: showsWings)
        let rect = CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
        // A little forgiveness: the closed notch is small, the open edge shouldn't be a cliff.
        return isOpen ? rect.insetBy(dx: -14, dy: -14) : rect.insetBy(dx: -6, dy: -3)
    }
}
