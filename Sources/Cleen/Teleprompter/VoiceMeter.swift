import Accelerate
import AVFoundation
import os

/// The microphone while the teleprompter reads, boiled down to how loud the voice is and
/// where its energy sits (low, low-mid, high-mid, high), for the glow behind the panel.
/// Nothing is recorded or kept: each buffer becomes those five numbers and is dropped.
///
/// The analysis runs on the audio thread; the ring reads the latest numbers on every
/// display frame, so nothing here goes through SwiftUI's observation.
@Observable
final class VoiceMeter {
    enum Access: Equatable {
        case unknown
        case granted
        case denied
    }

    /// Whether the ring follows the voice, as set beside Começar.
    static let enabledKey = "teleprompter.voiceRing"

    private(set) var access = Access.unknown
    private(set) var isListening = false

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?
    /// Still wanted once the permission prompt answers: the reading may have stopped.
    @ObservationIgnored private var isWanted = false
    @ObservationIgnored let levels = VoiceLevels()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Asks for the microphone the first time, then listens.
    func start() async {
        guard Self.isEnabled, !isListening else { return }
        isWanted = true
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: access = .granted
        case .notDetermined: access = await AVCaptureDevice.requestAccess(for: .audio) ? .granted : .denied
        default: access = .denied
        }
        guard access == .granted, isWanted, Self.isEnabled, engine == nil else { return }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap(into: levels, sampleRate: format.sampleRate))
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return
        }
        self.engine = engine
        isListening = true
        // AirPods connecting (or any input change) stops the engine: start over on the
        // new input.
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isWanted else { return }
                self.stopEngine()
                Task { await self.start() }
            }
        }
    }

    func stop() {
        isWanted = false
        stopEngine()
    }

    private func stopEngine() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isListening = false
        levels.reset()
    }

    /// Built outside the main actor: the block runs on the audio thread.
    private nonisolated static func tap(into levels: VoiceLevels, sampleRate: Double) -> AVAudioNodeTapBlock {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        return { buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            let reading = analyzer.analyze(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            levels.update(with: reading)
        }
    }
}

/// The latest reading, shared between the audio thread and the ring.
nonisolated final class VoiceLevels: Sendable {
    struct Reading: Sendable, Equatable {
        /// Overall loudness, 0 (silence) to 1 (speaking up).
        var level: Float = 0
        /// Energy in four bands, each 0 to 1.
        var bands: [Float] = [0, 0, 0, 0]
    }

    private let state = OSAllocatedUnfairLock(initialState: Reading())

    var current: Reading { state.withLock { $0 } }

    /// Quick to rise with the voice, slower to fall, so the ring breathes instead of
    /// flickering between syllables.
    func update(with raw: Reading) {
        state.withLock { smooth in
            smooth.level = Self.ease(smooth.level, raw.level)
            for index in smooth.bands.indices where index < raw.bands.count {
                smooth.bands[index] = Self.ease(smooth.bands[index], raw.bands[index])
            }
        }
    }

    func reset() {
        state.withLock { $0 = Reading() }
    }

    private static func ease(_ old: Float, _ new: Float) -> Float {
        old + (new - old) * (new > old ? 0.55 : 0.12)
    }
}

/// One FFT per buffer: a Hann window, magnitudes, then the mean energy of four bands of
/// the speaking voice, each mapped from decibels onto 0…1. Used only from the audio
/// thread, one buffer at a time.
nonisolated private final class SpectrumAnalyzer: @unchecked Sendable {
    private static let size = 1024
    private static let bands: [ClosedRange<Double>] = [80...300, 300...1_000, 1_000...3_000, 3_000...8_000]

    private let sampleRate: Double
    private let fft = vDSP.FFT(log2n: vDSP_Length(10), radix: .radix2, ofType: DSPSplitComplex.self)
    private let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
    private var windowed = [Float](repeating: 0, count: size)
    private var real = [Float](repeating: 0, count: size / 2)
    private var imaginary = [Float](repeating: 0, count: size / 2)
    private var magnitudes = [Float](repeating: 0, count: size / 2)

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func analyze(_ samples: UnsafeBufferPointer<Float>) -> VoiceLevels.Reading {
        let count = min(samples.count, Self.size)
        guard count > 0, let fft else { return .init() }

        // Loudness: RMS in decibels, -55 dB (a quiet room) to -10 dB (speaking up).
        let rms = vDSP.rootMeanSquare(UnsafeBufferPointer(rebasing: samples[0..<count]))
        let level = Self.normalized(decibels: 20 * log10(max(rms, 1e-7)), floor: -55, ceiling: -10)

        // Spectrum.
        for index in 0..<Self.size { windowed[index] = index < count ? samples[index] * window[index] : 0 }
        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imaginaryPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { input in
                    input.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.size / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(Self.size / 2))
                    }
                }
                fft.forward(input: split, output: &split)
                magnitudes.withUnsafeMutableBufferPointer { output in
                    vDSP_zvmags(&split, 1, output.baseAddress!, 1, vDSP_Length(Self.size / 2))
                }
            }
        }
        // Each band against the strongest one, in decibels over a 30 dB range, then
        // scaled by the loudness: the shape of the voice without calibrating any mic.
        let binWidth = sampleRate / Double(Self.size)
        let energies = Self.bands.map { band -> Float in
            let low = max(1, Int(band.lowerBound / binWidth)), high = min(magnitudes.count - 1, Int(band.upperBound / binWidth))
            guard high >= low else { return 1e-12 }
            return max(vDSP.mean(magnitudes[low...high]), 1e-12)
        }
        let strongest = energies.max() ?? 1e-12
        let bands = energies.map { Self.normalized(decibels: 10 * log10($0 / strongest), floor: -30, ceiling: 0) * level }
        return .init(level: level, bands: bands)
    }

    private static func normalized(decibels: Float, floor: Float, ceiling: Float) -> Float {
        min(1, max(0, (decibels - floor) / (ceiling - floor)))
    }
}
