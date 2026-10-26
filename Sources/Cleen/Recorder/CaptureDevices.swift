import AVFoundation

/// The cameras, microphones and plugged-in iPhones/iPads a recording can use.
nonisolated enum CaptureDevices {
    struct Device: Identifiable, Hashable {
        let id: String
        let name: String
        let isDefault: Bool
    }

    static func cameras() -> [Device] {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera], mediaType: .video, position: .unspecified)
        let standard = AVCaptureDevice.default(for: .video)?.uniqueID
        return session.devices.map { Device(id: $0.uniqueID, name: $0.localizedName, isDefault: $0.uniqueID == standard) }
    }

    static func microphones() -> [Device] {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
        let standard = AVCaptureDevice.default(for: .audio)?.uniqueID
        return session.devices.map { Device(id: $0.uniqueID, name: $0.localizedName, isDefault: $0.uniqueID == standard) }
    }

    /// iPhones and iPads connected by cable, which macOS shows as muxed (video + sound)
    /// capture devices once CoreMediaIO is asked for them.
    static func mobileDevices() -> [Device] {
        CameraCapture.allowScreenCaptureDevices()
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .muxed, position: .unspecified)
        return session.devices.map { Device(id: $0.uniqueID, name: $0.localizedName, isDefault: false) }
    }

    static func device(_ id: String) -> AVCaptureDevice? {
        AVCaptureDevice(uniqueID: id)
    }

    static var cameraAllowed: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
    static var microphoneAllowed: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }

    /// Asks once; answers whether it's allowed now.
    static func request(_ media: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: media)
        default: false
        }
    }
}
