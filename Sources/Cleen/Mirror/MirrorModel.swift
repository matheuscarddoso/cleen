import AVFoundation
import Observation

/// A quick look at yourself before a call. Asks for the camera once; after that the
/// mirror shows the live front camera whenever it's on screen.
@Observable
final class MirrorModel {
    enum Access: Equatable {
        case notAsked
        case granted
        case denied
    }

    private(set) var access: Access
    @ObservationIgnored let camera = CameraSession()
    /// One preview layer for the session, handed between the round and the wide mirror.
    /// A fresh layer per view stops receiving frames after the session restarts.
    @ObservationIgnored lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    @ObservationIgnored private var viewers = 0

    init() {
        access = Self.currentAccess()
    }

    /// The first tap asks for permission and, if given, turns the mirror on.
    func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        access = granted ? .granted : .denied
        if granted, viewers > 0 { camera.start { [weak self] in self?.fixOrientation() } }
    }

    /// Runs the camera while the calling view is visible.
    func appear() {
        viewers += 1
        access = Self.currentAccess()
        if access == .granted { camera.start { [weak self] in self?.fixOrientation() } }
    }

    /// The image exactly as the camera sees it. macOS mirrors front cameras on its own,
    /// so that has to be switched off explicitly, and only once the connection exists.
    func fixOrientation() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
    }

    /// Stops a moment later: when the round mirror grows into the wide one, the new
    /// view can appear before the old one disappears, and the camera must stay on.
    func disappear() {
        viewers = max(0, viewers - 1)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if viewers == 0 { camera.stop() }
        }
    }

    private static func currentAccess() -> Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }
}
