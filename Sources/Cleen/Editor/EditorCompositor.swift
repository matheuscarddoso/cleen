import AVFoundation
import CoreImage
import Metal

/// What the compositor gets for every stretch of the timeline: which tracks are the
/// screen and the camera, and where to read the scene from.
nonisolated final class EditorInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let screenTrack: CMPersistentTrackID
    let cameraTrack: CMPersistentTrackID?
    let scene: EditorSceneBox
    /// Seconds of the recording at the composition's zero (the trim's start).
    let offset: Double

    init(timeRange: CMTimeRange, screenTrack: CMPersistentTrackID, cameraTrack: CMPersistentTrackID?, scene: EditorSceneBox, offset: Double) {
        self.timeRange = timeRange
        self.screenTrack = screenTrack
        self.cameraTrack = cameraTrack
        self.scene = scene
        self.offset = offset
        requiredSourceTrackIDs = ([screenTrack] + (cameraTrack.map { [$0] } ?? [])).map { NSNumber(value: $0) }
    }
}

/// Renders each frame of the preview and the export with `EditorRenderer`, on Metal.
nonisolated final class EditorCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [.cacheIntermediates: false, .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        }
        return CIContext()
    }()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: any Sendable](),
    ]

    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: any Sendable](),
    ]

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? EditorInstruction,
              let scene = instruction.scene.scene,
              let output = request.renderContext.newPixelBuffer()
        else {
            request.finish(with: NSError(domain: "app.cleen.editor", code: 1))
            return
        }
        let screen = request.sourceFrame(byTrackID: instruction.screenTrack).map { CIImage(cvPixelBuffer: $0) }
        let camera = instruction.cameraTrack.flatMap { request.sourceFrame(byTrackID: $0) }.map { CIImage(cvPixelBuffer: $0) }
        let size = request.renderContext.size
        let time = request.compositionTime.seconds + instruction.offset
        let frame = EditorRenderer.render(screen: screen, camera: camera, time: time, canvas: size, scene: scene)
        context.render(frame, to: output, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        request.finish(withComposedVideoFrame: output)
    }

    func cancelAllPendingVideoCompositionRequests() {}
}
