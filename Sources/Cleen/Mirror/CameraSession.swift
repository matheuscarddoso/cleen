import AVFoundation

/// The front camera for the Mirror. Starting and stopping a capture session blocks for
/// a moment, so both happen on the session's own serial queue, never on the main thread.
final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.cleen.camera")
    private var configured = false

    func start() {
        queue.async { [self] in
            if !configured { configure() }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .medium
        let camera = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.first { $0.position == .front || $0.deviceType == .builtInWideAngleCamera }
            ?? AVCaptureDevice.default(for: .video)
        if let camera, let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
    }
}
