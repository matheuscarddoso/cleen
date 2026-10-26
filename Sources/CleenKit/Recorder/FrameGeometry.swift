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
