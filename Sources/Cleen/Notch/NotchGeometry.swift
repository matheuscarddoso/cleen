import AppKit

/// Where the notch is on a screen and how big the panel grows from it.
struct NotchGeometry: Equatable {
    /// The screen's full frame, in global (bottom-left origin) coordinates.
    let screenFrame: CGRect
    /// The camera housing, or a drawn stand-in on screens without one.
    let notchSize: CGSize
    let hasPhysicalNotch: Bool

    /// Width each live-activity wing adds beside the notch when it's closed.
    static let wingWidth = 60.0
    /// One size for every tool: switching tabs never resizes the panel.
    static let openPanelSize = CGSize(width: 680, height: 276)
    /// Room around the open panel for its shadow; the window is this much larger.
    static let shadowPadding = 36.0

    init(screen: NSScreen) {
        screenFrame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            notchSize = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
            hasPhysicalNotch = true
        } else {
            // No camera housing: draw a compact island the height of the menu bar.
            let menuBar = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            notchSize = CGSize(width: 180, height: menuBar)
            hasPhysicalNotch = false
        }
    }

    func closedSize(showsWings: Bool) -> CGSize {
        CGSize(width: notchSize.width + (showsWings ? Self.wingWidth * 2 : 0), height: notchSize.height)
    }

    var openSize: CGSize {
        CGSize(
            width: min(Self.openPanelSize.width, screenFrame.width - 40),
            height: Self.openPanelSize.height
        )
    }

    /// The panel window: as big as the open notch plus shadow, hanging from the top.
    var windowFrame: CGRect {
        let width = openSize.width + Self.shadowPadding * 2
        let height = openSize.height + Self.shadowPadding
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// The area that reacts to the pointer, in global coordinates.
    func hotZone(isOpen: Bool, showsWings: Bool) -> CGRect {
        let size = isOpen ? openSize : closedSize(showsWings: showsWings)
        let rect = CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
        // A little forgiveness: the closed notch is small, the open edge shouldn't be a cliff.
        return isOpen ? rect.insetBy(dx: -14, dy: -14) : rect.insetBy(dx: -6, dy: -3)
    }
}
