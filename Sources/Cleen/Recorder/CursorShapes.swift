import AppKit
import CleenKit

/// The system's cursors: telling which one is on screen while recording, and drawing
/// each one crisp (from the vector the system itself uses) for the editor.
enum CursorShapes {
    private static let known: [(NSCursor, CursorTrack.Shape)] = [
        (.arrow, .arrow), (.pointingHand, .pointingHand), (.iBeam, .iBeam), (.openHand, .openHand),
        (.closedHand, .closedHand), (.crosshair, .crosshair), (.resizeLeftRight, .resizeLeftRight),
        (.resizeUpDown, .resizeUpDown), (.operationNotAllowed, .notAllowed),
    ]

    /// The shape on screen now, by the cursor's hot spot and size (cheap enough for ten
    /// times a second, and distinct for each system cursor).
    static func current() -> CursorTrack.Shape? {
        guard let cursor = NSCursor.currentSystem else { return nil }
        let size = cursor.image.size
        return known.first { candidate, _ in
            abs(candidate.hotSpot.x - cursor.hotSpot.x) < 0.5 && abs(candidate.hotSpot.y - cursor.hotSpot.y) < 0.5
                && abs(candidate.image.size.width - size.width) < 0.5 && abs(candidate.image.size.height - size.height) < 0.5
        }?.1 ?? .arrow
    }

    /// Each shape drawn four times over with the system's shadow, as a Core Image image
    /// in points (its pixels stay sharp however far it's scaled), with its hot spot from
    /// the top-left.
    static func images() -> [CursorTrack.Shape: (image: CIImage, hotSpot: CGPoint)] {
        var result: [CursorTrack.Shape: (CIImage, CGPoint)] = [:]
        for (cursor, shape) in known {
            let source = vector(for: shape)
            let image = source?.image ?? cursor.image
            let hotSpot = source?.hotSpot ?? cursor.hotSpot
            if let drawn = draw(image, hotSpot: hotSpot) { result[shape] = drawn }
        }
        return result
    }

    private static let folder = URL(filePath: "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors")

    private static func vector(for shape: CursorTrack.Shape) -> (image: NSImage, hotSpot: CGPoint)? {
        let name: String? = switch shape {
        case .arrow: nil
        case .pointingHand: "pointinghand"
        case .iBeam: "ibeamhorizontal"
        case .openHand: "openhand"
        case .closedHand: "closedhand"
        case .crosshair: "cross"
        case .resizeLeftRight: "resizeleftright"
        case .resizeUpDown: "resizeupdown"
        case .notAllowed: "notallowed"
        }
        guard let name else { return nil }
        let dir = folder.appending(path: name, directoryHint: .isDirectory)
        guard let image = NSImage(contentsOf: dir.appending(path: "cursor.pdf")),
              let info = NSDictionary(contentsOf: dir.appending(path: "info.plist")),
              let x = info["hotx"] as? Double, let y = info["hoty"] as? Double
        else { return nil }
        return (image, CGPoint(x: x, y: y))
    }

    private static let scale: CGFloat = 4
    /// Room around the cursor for its shadow, in points.
    private static let margin: CGFloat = 3

    private static func draw(_ image: NSImage, hotSpot: CGPoint) -> (CIImage, CGPoint)? {
        let size = CGSize(width: image.size.width + margin * 2, height: image.size.height + margin * 2)
        let pixels = CGSize(width: (size.width * scale).rounded(.up), height: (size.height * scale).rounded(.up))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        // The system's own: 45% black, 2 pt blur, a point down.
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = CGSize(width: 0, height: -1)
        shadow.set()
        image.draw(in: CGRect(x: margin, y: margin, width: image.size.width, height: image.size.height))
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = bitmap.cgImage else { return nil }
        let ci = CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        return (ci, CGPoint(x: hotSpot.x + margin, y: hotSpot.y + margin))
    }
}
