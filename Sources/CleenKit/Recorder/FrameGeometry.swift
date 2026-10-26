import CoreGraphics
import Foundation

/// Where everything sits on the exported frame. Rects use a top-left origin in canvas
/// pixels; the renderer flips them for Core Image.
public enum FrameGeometry {
    /// The canvas for an aspect, its longer side `longSide`, in even pixels (encoders
    /// want even sizes).
    public static func canvas(aspect: EditorStyle.Aspect, source: CGSize, longSide: Double) -> CGSize {
        let ratio = aspect.ratio ?? (source.height > 0 ? source.width / source.height : 16.0 / 9)
        let size = ratio >= 1 ? CGSize(width: longSide, height: longSide / ratio) : CGSize(width: longSide * ratio, height: longSide)
        return CGSize(width: even(size.width), height: even(size.height))
    }

    /// The recording fitted inside the padding, keeping its own shape, centered.
    public static func contentRect(canvas: CGSize, source: CGSize, padding: Double) -> CGRect {
        let inset = min(canvas.width, canvas.height) * max(0, padding)
        let room = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)
        guard source.width > 0, source.height > 0, room.width > 0, room.height > 0 else { return room }
        let scale = min(room.width / source.width, room.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(x: room.midX - size.width / 2, y: room.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// The camera bubble: `size` of the canvas height, in a corner, kept clear of the
    /// edge by the same margin as the padding (or a small one without padding).
    public static func cameraRect(canvas: CGSize, style: EditorStyle.Camera, aspect cameraAspect: Double, padding: Double) -> CGRect {
        let height = canvas.height * style.size
        let width = style.shape == .square ? height * cameraAspect : height
        let margin = max(min(canvas.width, canvas.height) * padding * 0.6, min(canvas.width, canvas.height) * 0.03)
        let x = style.corner == .topLeft || style.corner == .bottomLeft ? margin : canvas.width - margin - width
        let y = style.corner == .topLeft || style.corner == .topRight ? margin : canvas.height - margin - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Where the screen and the camera sit for a layout.
    public struct Placement: Equatable, Sendable {
        /// Nil when only the camera shows.
        public var screen: CGRect?
        public var camera: CGRect?
        /// The camera floats in a corner (shaped by its own style) rather than taking a
        /// panel of the layout (rounded like the screen).
        public var cameraFloats: Bool
    }

    public static func placement(canvas: CGSize, source: CGSize, style: EditorStyle, cameraAspect: Double, hasCamera: Bool) -> Placement {
        let padding = style.effectivePadding
        let showsCamera = hasCamera && style.camera.isVisible
        let standard = Placement(
            screen: contentRect(canvas: canvas, source: source, padding: padding),
            camera: showsCamera ? cameraRect(canvas: canvas, style: style.camera, aspect: cameraAspect, padding: padding) : nil,
            cameraFloats: true
        )
        guard showsCamera else { return standard }
        let inset = min(canvas.width, canvas.height) * max(padding, 0.03)
        let room = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)
        switch style.layout {
        case .standard:
            return standard
        case .cameraOnly:
            return Placement(screen: nil, camera: room, cameraFloats: false)
        case .sideBySide:
            let gap = inset * 0.6
            guard source.width > 0, source.height > 0 else { return standard }
            if canvas.width >= canvas.height {
                // Side by side: the camera a third of the width, the screen fitted beside it.
                let cameraWidth = room.width * 0.3
                let screenRoom = CGSize(width: room.width - cameraWidth - gap, height: room.height)
                let scale = min(screenRoom.width / source.width, screenRoom.height / source.height)
                let screenSize = CGSize(width: source.width * scale, height: source.height * scale)
                let total = screenSize.width + gap + cameraWidth
                let x = room.minX + (room.width - total) / 2
                let screen = CGRect(x: x, y: room.midY - screenSize.height / 2, width: screenSize.width, height: screenSize.height)
                let camera = CGRect(x: screen.maxX + gap, y: screen.minY, width: cameraWidth, height: screenSize.height)
                return Placement(screen: screen, camera: camera, cameraFloats: false)
            } else {
                // Tall canvas: the screen on top, the camera below it.
                let scale = room.width / source.width
                let screenSize = CGSize(width: room.width, height: min(source.height * scale, room.height * 0.55))
                let screen = CGRect(x: room.minX, y: room.minY, width: screenSize.width, height: screenSize.height)
                let camera = CGRect(x: room.minX, y: screen.maxY + gap, width: room.width, height: room.maxY - screen.maxY - gap)
                return Placement(screen: screen, camera: camera, cameraFloats: false)
            }
        }
    }

    /// The canvas rect a zoom shows: `scale` times closer around `focus` (a canvas
    /// point), never past the canvas's edges.
    public static func viewport(canvas: CGSize, scale: Double, focus: CGPoint) -> CGRect {
        let size = CGSize(width: canvas.width / max(1, scale), height: canvas.height / max(1, scale))
        let x = min(canvas.width - size.width, max(0, focus.x - size.width / 2))
        let y = min(canvas.height - size.height, max(0, focus.y - size.height / 2))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// A point of the source (0…1, top-left) on the canvas, for a zoom state.
    public static func place(_ point: CGPoint, zoom: ZoomState, content: CGRect) -> CGPoint {
        let viewport = zoom.viewport
        let u = (point.x - viewport.minX) / viewport.width
        let v = (point.y - viewport.minY) / viewport.height
        return CGPoint(x: content.minX + u * content.width, y: content.minY + v * content.height)
    }

    static func even(_ value: Double) -> Double {
        let rounded = value.rounded()
        return Int(rounded) % 2 == 0 ? rounded : rounded + 1
    }
}
