import AppKit
import CleenKit
import CoreImage
import CoreImage.CIFilterBuiltins
import os

/// Everything a frame needs besides the video itself, swapped whole whenever an edit
/// lands so the compositor's threads always read a consistent set.
nonisolated struct EditorScene: @unchecked Sendable {
    var style: EditorStyle
    var zoom: [ZoomSegment]
    var sourceSize: CGSize
    var hasCamera: Bool
    /// The cursor as drawn.
    var cursor: CursorPath
    /// The cursor as the zoom follows it: smoothed much more, so the frame drifts
    /// instead of chasing every flick of the hand.
    var zoomFocus: CursorPath
    var clicks: [CursorTrack.Click]
    /// The pointer's picture and its hot spot (from the top-left, in points).
    var cursorImage: CIImage?
    var cursorHotSpot: CGPoint
    var wallpaper: CIImage?
}

/// The shared, lock-guarded scene the editor writes and the compositor reads.
nonisolated final class EditorSceneBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<EditorScene?>(initialState: nil)

    var scene: EditorScene? {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

/// Draws one finished frame: the background, the recording (zoomed, rounded, with its
/// shadow), the smoothed cursor and its clicks, and the camera bubble. Used for the
/// preview and the export alike, so what you see is what you get.
nonisolated enum EditorRenderer {
    static func render(screen: CIImage?, camera: CIImage?, time t: Double, canvas: CGSize, scene: EditorScene) -> CIImage {
        let bounds = CGRect(origin: .zero, size: canvas)
        var image = background(scene, bounds: bounds)
        let padding = scene.style.effectivePadding
        let content = FrameGeometry.contentRect(canvas: canvas, source: scene.sourceSize, padding: padding)
        let zoom = ZoomPlanner.state(at: t, segments: scene.zoom, pointer: { scene.zoomFocus.position(at: $0) })
        // Core Image's origin is bottom-left; the geometry's is top-left.
        let contentCI = flip(content, in: canvas)
        let radius = min(content.width, content.height) * scene.style.roundness

        if scene.style.shadow > 0, padding > 0 {
            let strength = scene.style.shadow
            let shape = roundedRect(contentCI, radius: radius, color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.55 * strength))
            let blur = min(canvas.width, canvas.height) * 0.03 * (0.5 + strength)
            let shadow = shape.applyingGaussianBlur(sigma: blur).transformed(by: CGAffineTransform(translationX: 0, y: -blur * 0.6)).cropped(to: bounds)
            image = shadow.composited(over: image)
        }

        if let screen {
            image = zoomed(screen, zoom: zoom, into: contentCI, radius: radius).composited(over: image)
        }

        if scene.style.showsClicks {
            for click in scene.clicks where t >= click.t && t - click.t < 0.45 {
                let progress = (t - click.t) / 0.45
                let point = flip(FrameGeometry.place(CGPoint(x: click.x, y: click.y), zoom: zoom, content: content), in: canvas)
                guard contentCI.contains(point) else { continue }
                let base = content.width / max(1, scene.sourceSize.width) * zoom.scale * 22
                image = ring(at: point, radius: base * (0.6 + progress), alpha: 0.55 * (1 - progress)).composited(over: image)
            }
        }

        if scene.style.showsCursor, let cursor = scene.cursorImage, let position = scene.cursor.position(at: t) {
            let point = flip(FrameGeometry.place(position, zoom: zoom, content: content), in: canvas)
            if contentCI.insetBy(dx: -2, dy: -2).contains(point) {
                // Real size on the canvas: the source's points scaled to the content, then
                // the zoom, then the person's choice.
                let scale = content.width / max(1, scene.sourceSize.width) * zoom.scale * scene.style.cursorSize
                let extent = cursor.extent
                let placed = cursor
                    .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    .transformed(by: CGAffineTransform(translationX: point.x - scene.cursorHotSpot.x * scale, y: point.y - (extent.height - scene.cursorHotSpot.y) * scale))
                image = placed.cropped(to: contentCI.insetBy(dx: -40, dy: -40)).composited(over: image)
            }
        }

        if let camera, scene.hasCamera, scene.style.camera.isVisible {
            image = bubble(camera, style: scene.style.camera, canvas: canvas, padding: padding).composited(over: image)
        }
        return image.cropped(to: bounds)
    }

    // MARK: Pieces

    private static func background(_ scene: EditorScene, bounds: CGRect) -> CIImage {
        switch scene.style.background {
        case .gradient(let index):
            let (start, end) = BackgroundPresets.colors(index)
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: bounds.minX, y: bounds.maxY)
            gradient.point1 = CGPoint(x: bounds.maxX, y: bounds.minY)
            gradient.color0 = start
            gradient.color1 = end
            return (gradient.outputImage ?? CIImage(color: start)).cropped(to: bounds)
        case .color(let hex):
            return CIImage(color: CIColor(hex: hex)).cropped(to: bounds)
        case .wallpaper:
            guard let wallpaper = scene.wallpaper else { return CIImage(color: .black).cropped(to: bounds) }
            let scale = max(bounds.width / wallpaper.extent.width, bounds.height / wallpaper.extent.height)
            let scaled = wallpaper.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let offset = CGAffineTransform(translationX: (bounds.width - scaled.extent.width) / 2 - scaled.extent.minX, y: (bounds.height - scaled.extent.height) / 2 - scaled.extent.minY)
            return scaled.transformed(by: offset).cropped(to: bounds)
        case .none:
            return CIImage(color: .black).cropped(to: bounds)
        }
    }

    /// The part of the screen the zoom shows, scaled into the content rect and rounded.
    private static func zoomed(_ screen: CIImage, zoom: ZoomState, into rect: CGRect, radius: CGFloat) -> CIImage {
        let extent = screen.extent
        let viewport = zoom.viewport
        let crop = CGRect(x: extent.minX + viewport.minX * extent.width, y: extent.minY + (1 - viewport.maxY) * extent.height,
                          width: viewport.width * extent.width, height: viewport.height * extent.height)
        let scaleX = rect.width / crop.width, scaleY = rect.height / crop.height
        let placed = screen.cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
            .cropped(to: rect)
        guard radius > 0.5 else { return placed }
        return placed.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: roundedRect(rect, radius: radius, color: .white),
        ])
    }

    private static func bubble(_ camera: CIImage, style: EditorStyle.Camera, canvas: CGSize, padding: Double) -> CIImage {
        let cameraAspect = camera.extent.width / max(1, camera.extent.height)
        let rect = flip(FrameGeometry.cameraRect(canvas: canvas, style: style, aspect: cameraAspect, padding: padding), in: canvas)
        // Aspect-fill the camera into the bubble.
        let scale = max(rect.width / camera.extent.width, rect.height / camera.extent.height)
        let scaled = camera.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let placed = scaled
            .transformed(by: CGAffineTransform(translationX: rect.midX - scaled.extent.midX, y: rect.midY - scaled.extent.midY))
            .cropped(to: rect)
        let radius: CGFloat = switch style.shape {
        case .circle: rect.width / 2
        case .rounded: min(rect.width, rect.height) * 0.18
        case .square: min(rect.width, rect.height) * 0.04
        }
        let masked = placed.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: roundedRect(rect, radius: radius, color: .white),
        ])
        let shadow = roundedRect(rect, radius: radius, color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.45))
            .applyingGaussianBlur(sigma: rect.height * 0.06)
            .transformed(by: CGAffineTransform(translationX: 0, y: -rect.height * 0.03))
        return masked.composited(over: shadow)
    }

    private static func ring(at point: CGPoint, radius: CGFloat, alpha: Double) -> CIImage {
        let gradient = CIFilter.radialGradient()
        gradient.center = point
        gradient.radius0 = Float(radius * 0.82)
        gradient.radius1 = Float(radius)
        gradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        gradient.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: alpha)
        let outer = CIFilter.radialGradient()
        outer.center = point
        outer.radius0 = Float(radius)
        outer.radius1 = Float(radius + 1.5)
        outer.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: alpha)
        outer.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        let box = CGRect(x: point.x - radius - 2, y: point.y - radius - 2, width: (radius + 2) * 2, height: (radius + 2) * 2)
        guard let inner = gradient.outputImage, let edge = outer.outputImage else { return .empty() }
        let disc = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: alpha * 0.25))
            .applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: roundedRect(box.insetBy(dx: 2, dy: 2), radius: radius, color: .white)])
        return edge.cropped(to: box).composited(over: inner.cropped(to: box)).composited(over: disc.cropped(to: box))
    }

    private static func roundedRect(_ rect: CGRect, radius: CGFloat, color: CIColor) -> CIImage {
        let generator = CIFilter.roundedRectangleGenerator()
        generator.extent = rect
        generator.radius = Float(min(radius, min(rect.width, rect.height) / 2))
        generator.color = color
        return generator.outputImage ?? .empty()
    }

    /// A top-left-origin rect or point in Core Image's bottom-left space.
    static func flip(_ rect: CGRect, in canvas: CGSize) -> CGRect {
        CGRect(x: rect.minX, y: canvas.height - rect.maxY, width: rect.width, height: rect.height)
    }

    static func flip(_ point: CGPoint, in canvas: CGSize) -> CGPoint {
        CGPoint(x: point.x, y: canvas.height - point.y)
    }
}
