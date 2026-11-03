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
    /// The tabs' dock under the open panel: its height (one row, folded or expanded; see
    /// `NotchDockLayout`) and the gap above it.
    static let dockHeight = NotchDockLayout.height
    static let dockGap = 8.0
    /// What the dock gave back to the panel: the tab bar inside it took 42 pt; the tool now
    /// keeps a 14 pt inset at the bottom instead.
    static let dockSavings = 28.0

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
        closedSize(.symmetric(wingWidth))
    }

    func closedSize(_ wings: ClosedWings) -> CGSize {
        CGSize(width: notchSize.width + wings.leading + wings.trailing, height: notchSize.height)
    }

    /// What a wing's content sits in from the notch's edges: the gap the artwork leaves
    /// above and below it, used on every side so the content is equally far from the
    /// bottom, the outer edge and the camera, and its corners are concentric with the
    /// notch's (`closedBottomRadius - inset`).
    static func wingInset(notchHeight: Double) -> Double {
        (notchHeight - wingArtworkSize(notchHeight: notchHeight)) / 2
    }

    /// Artwork as large as the notch allows, up to 20 pt.
    static func wingArtworkSize(notchHeight: Double) -> Double { min(20, notchHeight - 8) }

    /// A wing just wide enough for `content`: the shoulder's curve, the inset, the
    /// content and the inset again before the camera. No content, no wing.
    func wingWidth(fitting content: Double) -> Double {
        guard content > 0 else { return 0 }
        return NotchStyle.closedTopRadius + Self.wingInset(notchHeight: notchSize.height) * 2 + content
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
        /// A tool that's one bar (Gravar): the camera strip, the bar and the tab bar.
        case compact
        /// Início being edited: the dock steps aside, and the outlines, the size pickers
        /// and the bar above need the room it had.
        case editing
        /// During a call: the strip with the app and time, and the four controls.
        case call
    }

    func openSize(_ height: PanelHeight) -> CGSize {
        let width = min(Self.openPanelSize.width, screenFrame.width - 40)
        let standard = Self.openPanelSize.height
        switch height {
        case .standard:
            return CGSize(width: width, height: standard - Self.dockSavings)
        case .tall:
            return CGSize(width: width, height: max(standard, min(Self.searchHeight, screenFrame.height * 0.6)))
        case .call:
            return CGSize(width: width, height: notchSize.height + 6 + 26 + 54 + 18)
        case .editing:
            return CGSize(width: width, height: standard - 6)
        case .compact:
            // The camera strip, 6 pt, the 64 pt bar and the bottom inset.
            return CGSize(width: width, height: min(standard, notchSize.height + 6 + 64 + 14))
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
        let height = size.height + Self.dockGap + Self.dockHeight + Self.shadowPadding
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// The area that reacts to the pointer, in global coordinates. `dockHeight` is the
    /// dock's height when it shows (0 when it doesn't); `wings`, the closed notch's wings
    /// as drawn (the default wing on both sides when not given).
    func hotZone(isOpen: Bool, showsWings: Bool, height: PanelHeight = .standard, dockHeight: Double = 0, wings: ClosedWings? = nil) -> CGRect {
        let closedWings = wings ?? .symmetric(showsWings ? Self.wingWidth : 0)
        let size = isOpen ? openSize(height) : closedSize(closedWings)
        // The dock below counts as the panel: reaching for a tab never closes it.
        let reach = isOpen && dockHeight > 0 ? Self.dockGap + dockHeight : 0
        // Closed, wings of different widths shift the notch off the camera's centre.
        let shift = isOpen ? 0 : closedWings.offset
        let rect = CGRect(x: screenFrame.midX - size.width / 2 + shift, y: screenFrame.maxY - size.height - reach, width: size.width, height: size.height + reach)
        // A little forgiveness: the closed notch is small, the open edge shouldn't be a cliff.
        return isOpen ? rect.insetBy(dx: -14, dy: -14) : rect.insetBy(dx: -6, dy: -3)
    }
}

/// How far the closed notch reaches past the camera on each side. Each wing is as wide as
/// what it holds, so the two can differ: the notch then sits off-centre by `offset`.
struct ClosedWings: Equatable {
    var leading: Double
    var trailing: Double

    static let none = ClosedWings(leading: 0, trailing: 0)

    static func symmetric(_ width: Double) -> ClosedWings { ClosedWings(leading: width, trailing: width) }

    var isEmpty: Bool { leading <= 0 && trailing <= 0 }

    /// How far the notch's centre moves right of the camera's.
    var offset: Double { (trailing - leading) / 2 }
}

/// The closed wings' content as laid out, measured by `NotchWings`.
struct WingContent: Equatable {
    var leading = 0.0
    var trailing = 0.0

    var isMeasured: Bool { leading > 0 || trailing > 0 }
}
