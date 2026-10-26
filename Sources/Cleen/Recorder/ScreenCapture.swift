import AVFoundation
import os
import ScreenCaptureKit

/// The screen side of a recording: a ScreenCaptureKit stream written straight to a movie
/// by `SCRecordingOutput`, with the Mac's sound and the microphone as audio tracks. The
/// system cursor is left out; the editor draws its own from the cursor track.
nonisolated final class ScreenCapture: NSObject, SCStreamDelegate, SCStreamOutput, SCRecordingOutputDelegate, @unchecked Sendable {
    enum Target {
        /// A whole display, or the `area` of it (points, top-left origin, in the display).
        case display(SCDisplay, area: CGRect?)
        case window(SCWindow)
    }

    struct Options {
        var framesPerSecond = 60
        var systemAudio = false
        var microphoneID: String?
    }

    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "recorder")
    private let queue = DispatchQueue(label: "app.cleen.recorder.screen", qos: .userInitiated)
    private var stream: SCStream?
    private var output: SCRecordingOutput?
    private var started: CheckedContinuation<Void, Error>?
    private var finished: CheckedContinuation<Void, Error>?
    /// The size of what's recorded, in points.
    private(set) var contentSize = CGSize.zero

    /// Starts writing to `url`; returns once the first frame is in the file.
    nonisolated(nonsending) func start(_ target: Target, excluding: [SCWindow], options: Options, to url: URL) async throws {
        let filter: SCContentFilter
        let configuration = SCStreamConfiguration()
        switch target {
        case .display(let display, let area):
            filter = SCContentFilter(display: display, excludingWindows: excluding)
            if let area {
                configuration.sourceRect = area
                contentSize = area.size
            } else {
                contentSize = filter.contentRect.size
            }
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
            contentSize = filter.contentRect.size
        }
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int((contentSize.width * scale).rounded())
        configuration.height = Int((contentSize.height * scale).rounded())
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(options.framesPerSecond))
        configuration.queueDepth = 6
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.capturesAudio = options.systemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        if let microphone = options.microphoneID {
            configuration.captureMicrophone = true
            configuration.microphoneCaptureDeviceID = microphone
        }

        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = url
        recording.outputFileType = .mov
        recording.videoCodecType = recording.availableVideoCodecTypes.contains(.hevc) ? .hevc : .h264
        let output = SCRecordingOutput(configuration: recording, delegate: self)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        // The stream wants a frame consumer of its own besides the file.
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try stream.addRecordingOutput(output)
        self.stream = stream
        self.output = output
        try await withCheckedThrowingContinuation { continuation in
            started = continuation
            stream.startCapture { error in
                if let error { self.resume(&self.started, with: error) }
            }
        }
    }

    /// Stops and waits for the file to be closed.
    nonisolated(nonsending) func stop() async throws {
        guard let stream else { return }
        try await withCheckedThrowingContinuation { continuation in
            finished = continuation
            stream.stopCapture { error in
                if let error { self.resume(&self.finished, with: error) }
            }
        }
        self.stream = nil
        output = nil
    }

    // MARK: Delegates

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        resume(&started, with: nil)
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        Self.log.error("recording failed: \(error.localizedDescription, privacy: .public)")
        resume(&started, with: error)
        resume(&finished, with: error)
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        resume(&finished, with: nil)
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Self.log.error("stream stopped: \(error.localizedDescription, privacy: .public)")
        resume(&started, with: error)
        resume(&finished, with: error)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}

    private func resume(_ continuation: inout CheckedContinuation<Void, Error>?, with error: Error?) {
        guard let pending = continuation else { return }
        continuation = nil
        if let error { pending.resume(throwing: error) } else { pending.resume() }
    }
}
