import AppKit
import CleenKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import os

/// Everything a frame needs besides the video itself, swapped whole whenever an edit
/// lands so the compositor's threads always read a consistent set.
nonisolated struct EditorScene: @unchecked Sendable {
    var style: EditorStyle
    var zoom: [ZoomSegment]
    var sourceSize: CGSize
    /// The part of the recording shown (0…1, top-left); nil is all of it.
    var crop: CGRect?
    var timeline: EditTimeline
    var hasCamera: Bool
    /// The cursor as drawn.
    var cursor: CursorPath
    /// The cursor as the zoom follows it: smoothed much more, so the frame drifts
    /// instead of chasing every flick of the hand.
    var zoomFocus: CursorPath
    var clicks: [CursorTrack.Click]
    /// Each pointer shape's picture and its hot spot (from the top-left, in points).
    var cursors: [CursorTrack.Shape: (image: CIImage, hotSpot: CGPoint)]
    /// Which shape the pointer had when.
    var shapes: CursorTrack
    /// The picture behind the recording, when the background is one.
    var backgroundImage: CIImage?

    /// The shown part's size, in points.
    var croppedSize: CGSize {
        guard let crop else { return sourceSize }
        return CGSize(width: sourceSize.width * crop.width, height: sourceSize.height * crop.height)
    }

    /// A point of the recording (0…1) in the shown part's terms.
    func cropped(_ point: CGPoint) -> CGPoint {
        guard let crop, crop.width > 0, crop.height > 0 else { return point }
        return CGPoint(x: (point.x - crop.minX) / crop.width, y: (point.y - crop.minY) / crop.height)
    }
}

/// The shared, lock-guarded scene the editor writes and the compositor reads.
nonisolated final class EditorSceneBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<EditorScene?>(initialState: nil)

    var scene: EditorScene? {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

/// Draws one finished frame: the background, the recording (rounded, with its shadow),
/// the smoothed cursor and its clicks, the camera, and the zoom over all of it. Used for
/// the preview and the export alike, so what you see is what you get.
nonisolated enum EditorRenderer {
    /// `time` is the finished video's; the cursor and the zooms read the recording's.
    static func render(screen: CIImage?, camera: CIImage?, time output: Double, canvas: CGSize, scene: EditorScene) -> CIImage {
        let t = scene.timeline.sourceTime(at: output)
        let bounds = CGRect(origin: .zero, size: canvas)
        let style = scene.style
        let cameraAspect = camera.map { $0.extent.width / max(1, $0.extent.height) } ?? 16.0 / 9
        let placement = FrameGeometry.placement(canvas: canvas, source: scene.croppedSize, style: style, cameraAspect: cameraAspect, hasCamera: scene.hasCamera && camera != nil)
        let zoom = ZoomPlanner.state(at: t, segments: scene.zoom, clamped: false) { time in
            scene.zoomFocus.position(at: time).map(scene.cropped)
        }
        // Side by side, the zoom stays inside the screen's panel; otherwise it moves the
        // whole frame, background and all, as Screen Studio does.
        let zoomsInPanel = !placement.cameraFloats
        // The background and the screen's shadow don't move during the video: drawn once
        // (blurs over the whole frame are the costly part) and reused every frame.
        let screenRadius: CGFloat = if let screen = placement.screen { min(screen.width, screen.height) * CGFloat(style.roundness) } else { 0 }
        let staticKey = StaticLayers.Key(canvas: canvas, background: style.background, blur: style.backgroundBlur, screen: placement.screen, radius: screenRadius, shadow: style.effectivePadding > 0 ? style.shadow : 0)
        var stage = StaticLayers.shared.image(for: staticKey) {
            var base = background(scene, bounds: bounds)
            if let content = placement.screen, style.shadow > 0, style.effectivePadding > 0 {
                base = shadow(flip(content, in: canvas), radius: screenRadius, strength: style.shadow, canvas: canvas).composited(over: base)
            }
            return base
        }

        if let content = placement.screen {
            let contentCI = flip(content, in: canvas)
            let radius = screenRadius
            if let screen {
                let panelZoom = zoomsInPanel ? ZoomState(scale: zoom.scale, center: ZoomPlanner.clamp(zoom.center, scale: zoom.scale)) : .none
                stage = place(screen, crop: scene.crop, zoom: panelZoom, into: contentCI, radius: radius).composited(over: stage)
            }
            let pointZoom = zoomsInPanel ? ZoomState(scale: zoom.scale, center: ZoomPlanner.clamp(zoom.center, scale: zoom.scale)) : .none
            // Real size on the canvas: the source's points scaled to the content.
            let pointScale = content.width / max(1, scene.croppedSize.width) * pointZoom.scale
            if style.showsClicks {
                for click in scene.clicks where t >= click.t && t - click.t < 0.5 {
                    let progress = (t - click.t) / 0.5
                    let point = flip(FrameGeometry.place(scene.cropped(CGPoint(x: click.x, y: click.y)), zoom: pointZoom, content: content), in: canvas)
                    guard contentCI.contains(point) else { continue }
                    stage = clickEffect(at: point, size: pointScale * 18 * style.cursorSize / 1.6, progress: progress).composited(over: stage)
                }
            }
            if style.showsCursor, let drawn = scene.cursors[scene.shapes.shape(at: t)] ?? scene.cursors[.arrow], let position = scene.cursor.position(at: t) {
                let cursor = drawn.image
                let point = flip(FrameGeometry.place(scene.cropped(position), zoom: pointZoom, content: content), in: canvas)
                if contentCI.insetBy(dx: -2, dy: -2).contains(point) {
                    let scale = pointScale * style.cursorSize
                    let extent = cursor.extent
                    let placed = cursor
                        .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        .transformed(by: CGAffineTransform(translationX: point.x - drawn.hotSpot.x * scale, y: point.y - (extent.height - drawn.hotSpot.y) * scale))
                    stage = placed.cropped(to: contentCI.insetBy(dx: -60, dy: -60)).composited(over: stage)
                }
            }
        }

        if let camera, let rect = placement.camera, !placement.cameraFloats {
            let radius = min(rect.width, rect.height) * max(style.roundness, 0.02) * 1.6
            stage = panel(camera, in: flip(rect, in: canvas), radius: radius, canvas: canvas).composited(over: stage)
        }

        var image = stage
        if !zoomsInPanel, zoom.scale > 1.001, let content = placement.screen {
            let focus = CGPoint(x: content.minX + zoom.center.x * content.width, y: content.minY + zoom.center.y * content.height)
            let viewport = flip(FrameGeometry.viewport(canvas: canvas, scale: zoom.scale, focus: focus), in: canvas)
            image = stage
                .transformed(by: CGAffineTransform(translationX: -viewport.minX, y: -viewport.minY))
                .transformed(by: CGAffineTransform(scaleX: zoom.scale, y: zoom.scale))
                .cropped(to: bounds)
        }

        if let camera, let rect = placement.camera, placement.cameraFloats {
            image = bubble(camera, style: style.camera, rect: flip(rect, in: canvas)).composited(over: image)
        }
        return image.cropped(to: bounds)
    }

    // MARK: Pieces

    private static func background(_ scene: EditorScene, bounds: CGRect) -> CIImage {
        let base: CIImage
        switch scene.style.background {
        case .gradient(let index):
            let (start, end) = BackgroundPresets.colors(index)
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: bounds.minX, y: bounds.maxY)
            gradient.point1 = CGPoint(x: bounds.maxX, y: bounds.minY)
            gradient.color0 = start
            gradient.color1 = end
            base = (gradient.outputImage ?? CIImage(color: start)).cropped(to: bounds)
        case .color(let hex):
            base = CIImage(color: CIColor(hex: hex)).cropped(to: bounds)
        case .wallpaper, .picture:
            guard let picture = scene.backgroundImage else { return CIImage(color: .black).cropped(to: bounds) }
            let scale = max(bounds.width / picture.extent.width, bounds.height / picture.extent.height)
            let scaled = picture.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let offset = CGAffineTransform(translationX: (bounds.width - scaled.extent.width) / 2 - scaled.extent.minX, y: (bounds.height - scaled.extent.height) / 2 - scaled.extent.minY)
            base = scaled.transformed(by: offset).cropped(to: bounds)
        case .none:
            return CIImage(color: .black).cropped(to: bounds)
        }
        guard scene.style.backgroundBlur > 0.01 else { return base }
        let sigma = min(bounds.width, bounds.height) * 0.04 * scene.style.backgroundBlur
        return base.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: bounds)
    }

    private static func shadow(_ rect: CGRect, radius: CGFloat, strength: Double, canvas: CGSize) -> CIImage {
        let shape = roundedRect(rect, radius: radius, color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.55 * strength))
        let blur = min(canvas.width, canvas.height) * 0.03 * (0.5 + strength)
        return shape.applyingGaussianBlur(sigma: blur)
            .transformed(by: CGAffineTransform(translationX: 0, y: -blur * 0.6))
            .cropped(to: CGRect(origin: .zero, size: canvas))
    }

    /// The shown part of the screen (the crop, then the zoom's view of it), scaled into
    /// `rect` and rounded.
    private static func place(_ screen: CIImage, crop: CGRect?, zoom: ZoomState, into rect: CGRect, radius: CGFloat) -> CIImage {
        let extent = screen.extent
        let shown = crop ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let viewport = zoom.viewport
        // The viewport is in the crop's terms; both are top-left, Core Image is bottom-left.
        let region = CGRect(
            x: shown.minX + viewport.minX * shown.width,
            y: shown.minY + viewport.minY * shown.height,
            width: viewport.width * shown.width,
            height: viewport.height * shown.height
        )
        let source = CGRect(x: extent.minX + region.minX * extent.width, y: extent.minY + (1 - region.maxY) * extent.height,
                            width: region.width * extent.width, height: region.height * extent.height)
        let placed = screen.cropped(to: source)
            .transformed(by: CGAffineTransform(translationX: -source.minX, y: -source.minY))
            .transformed(by: CGAffineTransform(scaleX: rect.width / source.width, y: rect.height / source.height))
            .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
            .cropped(to: rect)
        guard radius > 0.5 else { return placed }
        return masked(placed, by: roundedRect(rect, radius: radius, color: .white))
    }

    /// The camera as one of the layout's panels: filling its rect, rounded like the screen.
    private static func panel(_ camera: CIImage, in rect: CGRect, radius: CGFloat, canvas: CGSize) -> CIImage {
        let filled = masked(fill(camera, into: rect), by: roundedRect(rect, radius: radius, color: .white))
        return filled.composited(over: shadow(rect, radius: radius, strength: 0.5, canvas: canvas))
    }

    private static func bubble(_ camera: CIImage, style: EditorStyle.Camera, rect: CGRect) -> CIImage {
        let mask: CIImage = switch style.shape {
        case .circle: roundedRect(rect, radius: rect.width / 2, color: .white)
        case .rounded: squircle(rect)
        case .square: roundedRect(rect, radius: min(rect.width, rect.height) * 0.04, color: .white)
        }
        let radius = style.shape == .circle ? rect.width / 2 : min(rect.width, rect.height) * 0.2
        let shadow = StaticLayers.shared.shadow(rect: rect, radius: radius) {
            roundedRect(rect, radius: radius, color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.45))
                .applyingGaussianBlur(sigma: rect.height * 0.06)
                .transformed(by: CGAffineTransform(translationX: 0, y: -rect.height * 0.03))
        }
        return masked(fill(camera, into: rect), by: mask).composited(over: shadow)
    }

    /// Aspect-fills `image` into `rect`.
    private static func fill(_ image: CIImage, into rect: CGRect) -> CIImage {
        let scale = max(rect.width / image.extent.width, rect.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scaled
            .transformed(by: CGAffineTransform(translationX: rect.midX - scaled.extent.midX, y: rect.midY - scaled.extent.midY))
            .cropped(to: rect)
    }

    private static func masked(_ image: CIImage, by mask: CIImage) -> CIImage {
        image.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: mask,
        ])
    }

    /// Where the pointer clicked: a soft disc and a thin ring that grow and fade, cut to
    /// a circle (a radial gradient keeps its last color past its radius, so without the
    /// cut it fills its whole box).
    private static func clickEffect(at point: CGPoint, size: CGFloat, progress: Double) -> CIImage {
        let eased = 1 - pow(1 - progress, 3)
        let radius = size * (0.55 + 0.75 * eased)
        let alpha = 0.7 * (1 - progress)
        let circle = CIFilter.radialGradient()
        circle.center = point
        circle.radius0 = Float(radius)
        circle.radius1 = Float(radius + 1.2)
        circle.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        circle.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        let edge = CIFilter.radialGradient()
        edge.center = point
        edge.radius0 = Float(radius - max(1.5, size * 0.09))
        edge.radius1 = Float(radius - max(1.5, size * 0.09) + 1.2)
        edge.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        edge.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: alpha)
        let box = CGRect(x: point.x - radius - 3, y: point.y - radius - 3, width: (radius + 3) * 2, height: (radius + 3) * 2)
        guard let inside = circle.outputImage, let ring = edge.outputImage else { return .empty() }
        let disc = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: alpha * 0.28))
        let shape = ring.composited(over: disc)
        return shape.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: inside]).cropped(to: box)
    }

    /// Screen Studio's camera squircle as a mask, drawn once per size.
    private static func squircle(_ rect: CGRect) -> CIImage {
        let size = CGSize(width: rect.width.rounded(), height: rect.height.rounded())
        let image = SquircleMasks.shared.mask(size: size)
        return image.transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
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

/// Squircle masks by size: the camera bubble stays one size for a whole export, so it's
/// drawn once instead of every frame.
nonisolated final class SquircleMasks: @unchecked Sendable {
    static let shared = SquircleMasks()
    private let cache = OSAllocatedUnfairLock<[CGSize: CIImage]>(initialState: [:])

    func mask(size: CGSize) -> CIImage {
        if let cached = cache.withLock({ $0[size] }) { return cached }
        let width = max(1, Int(size.width)), height = max(1, Int(size.height))
        // White on clear: the blend reads the mask's alpha.
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .empty() }
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.addPath(Squircle.path(in: CGRect(x: 0, y: 0, width: width, height: height)))
        context.fillPath()
        guard let image = context.makeImage() else { return .empty() }
        let mask = CIImage(cgImage: image)
        cache.withLock { cache in
            if cache.count > 8 { cache.removeAll() }
            cache[size] = mask
        }
        return mask
    }
}

/// The frame's still parts (the background with its blur, the screen's shadow, the
/// camera bubble's shadow), rendered to pixels once and reused: redrawing those blurs
/// every frame is what made the preview stutter.
nonisolated final class StaticLayers: @unchecked Sendable {
    static let shared = StaticLayers()

    struct Key: Hashable {
        let canvas: CGSize
        let background: EditorStyle.Background
        let blur: Double
        let screen: CGRect?
        let radius: CGFloat
        let shadow: Double
    }

    private struct ShadowKey: Hashable {
        let rect: CGRect
        let radius: CGFloat
    }

    private let lock = OSAllocatedUnfairLock<(base: [Key: CIImage], shadows: [ShadowKey: CIImage])>(initialState: ([:], [:]))
    private let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: device, options: [.cacheIntermediates: false]) }
        return CIContext()
    }()

    func image(for key: Key, make: () -> CIImage) -> CIImage {
        if let cached = lock.withLock({ $0.base[key] }) { return cached }
        let image = rasterize(make(), in: CGRect(origin: .zero, size: key.canvas))
        lock.withLock { state in
            // A handful is plenty: preview and export sizes, and the last few styles.
            if state.base.count > 6 { state.base.removeAll() }
            state.base[key] = image
        }
        return image
    }

    func shadow(rect: CGRect, radius: CGFloat, make: () -> CIImage) -> CIImage {
        let key = ShadowKey(rect: rect, radius: radius)
        if let cached = lock.withLock({ $0.shadows[key] }) { return cached }
        let made = make()
        let image = rasterize(made, in: made.extent.insetBy(dx: -1, dy: -1).integral)
        lock.withLock { state in
            if state.shadows.count > 12 { state.shadows.removeAll() }
            state.shadows[key] = image
        }
        return image
    }

    private func rasterize(_ image: CIImage, in rect: CGRect) -> CIImage {
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0,
              let cgImage = context.createCGImage(image, from: rect) else { return image }
        return CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}
