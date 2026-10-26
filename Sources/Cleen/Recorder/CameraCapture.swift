import AVFoundation
import CoreMediaIO
import os

/// A camera (or an iPhone/iPad's screen, which macOS exposes as a camera) written to its
/// own movie, so the editor can place and shape it freely.
nonisolated final class CameraCapture: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "recorder")
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "app.cleen.recorder.camera")
    private var started: CheckedContinuation<Void, Error>?
    private var finished: CheckedContinuation<Void, Error>?

    /// Sets the session up for `device`, its picture capped at `maxHeight` lines. Muxed
    /// devices (an iPhone's screen) bring their own sound.
    func configure(device: AVCaptureDevice, maxHeight: Int) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(output) else { throw CameraError.unavailable }
        session.addInput(input)
        session.addOutput(output)
        for preset in Self.presets(upTo: maxHeight) where session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
            break
        }
    }

    func startSession() {
        queue.async { self.session.startRunning() }
    }

    func start(to url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            started = continuation
            queue.async {
                if !self.session.isRunning { self.session.startRunning() }
                self.output.startRecording(to: url, recordingDelegate: self)
            }
        }
    }

    func stop() async throws {
        guard output.isRecording else {
            queue.async { self.session.stopRunning() }
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            finished = continuation
            queue.async { self.output.stopRecording() }
        }
        queue.async { self.session.stopRunning() }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        let pending = started
        started = nil
        pending?.resume()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        // AVFoundation reports a normal stop as an "error" that still finished the file.
        let completed = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        if let error, !completed { Self.log.error("camera recording failed: \(error.localizedDescription, privacy: .public)") }
        let starting = started
        started = nil
        let pending = finished
        finished = nil
        if completed {
            starting?.resume()
            pending?.resume()
        } else {
            starting?.resume(throwing: error ?? CameraError.unavailable)
            pending?.resume(throwing: error ?? CameraError.unavailable)
        }
    }

    enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? { String(localized: "A câmera não está disponível.") }
    }

    private static func presets(upTo height: Int) -> [AVCaptureSession.Preset] {
        let all: [(Int, AVCaptureSession.Preset)] = [(2160, .hd4K3840x2160), (1080, .hd1920x1080), (720, .hd1280x720), (480, .vga640x480)]
        return all.filter { $0.0 <= height }.map(\.1) + [.high]
    }

    /// iPhones and iPads plugged in by cable only show up as capture devices once an app
    /// asks CoreMediaIO for them.
    static func allowScreenCaptureDevices() {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &allow)
    }
}
