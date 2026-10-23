import CoreGraphics

/// Where a window goes for each window command, as a fraction of the screen's usable
/// area (below the menu bar, beside the Dock). Top-left origin, like Accessibility.
public enum WindowLayout: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case maximize, almostMaximize, center

    /// The window's new frame inside `area`. `current` matters only for `center`,
    /// which keeps the window's size.
    public func frame(in area: CGRect, current: CGRect) -> CGRect {
        let x = area.minX, y = area.minY, w = area.width, h = area.height
        switch self {
        case .leftHalf: return CGRect(x: x, y: y, width: w / 2, height: h)
        case .rightHalf: return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .topHalf: return CGRect(x: x, y: y, width: w, height: h / 2)
        case .bottomHalf: return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .topLeft: return CGRect(x: x, y: y, width: w / 2, height: h / 2)
        case .topRight: return CGRect(x: x + w / 2, y: y, width: w / 2, height: h / 2)
        case .bottomLeft: return CGRect(x: x, y: y + h / 2, width: w / 2, height: h / 2)
        case .bottomRight: return CGRect(x: x + w / 2, y: y + h / 2, width: w / 2, height: h / 2)
        case .firstThird: return CGRect(x: x, y: y, width: w / 3, height: h)
        case .centerThird: return CGRect(x: x + w / 3, y: y, width: w / 3, height: h)
        case .lastThird: return CGRect(x: x + 2 * w / 3, y: y, width: w / 3, height: h)
        case .firstTwoThirds: return CGRect(x: x, y: y, width: 2 * w / 3, height: h)
        case .lastTwoThirds: return CGRect(x: x + w / 3, y: y, width: 2 * w / 3, height: h)
        case .maximize: return area
        case .almostMaximize: return area.insetBy(dx: w * 0.05, dy: h * 0.05)
        case .center:
            let size = CGSize(width: min(current.width, w), height: min(current.height, h))
            return CGRect(x: x + (w - size.width) / 2, y: y + (h - size.height) / 2, width: size.width, height: size.height)
        }
    }

    /// The same placement on another screen, keeping the window's relative position and
    /// size: "send to the next display".
    public static func moved(_ window: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let width = min(target.width, window.width * target.width / max(1, source.width))
        let height = min(target.height, window.height * target.height / max(1, source.height))
        let relativeX = (window.minX - source.minX) / max(1, source.width)
        let relativeY = (window.minY - source.minY) / max(1, source.height)
        let x = min(target.maxX - width, max(target.minX, target.minX + relativeX * target.width))
        let y = min(target.maxY - height, max(target.minY, target.minY + relativeY * target.height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
