import AVFoundation

/// The tour's few sounds, synthesised on the spot (bell-like partials through a hall
/// reverb) so Cleen ships no audio files. Quiet by design, and one tap mutes them.
///
/// Everything audio runs on its own queue: rendering the chords is millions of samples
/// and starting the engine can take a while, and on the main thread either one froze
/// the titles right as the wordmark came in. `isMuted` belongs to the main thread.
nonisolated final class OnboardingSound: @unchecked Sendable {
    enum Cue {
        /// The wordmark arriving: a slow, rising chord.
        case shimmer
        /// Moving to the next page.
        case tick
        /// A permission coming through.
        case success
        /// The end of the tour.
        case fanfare
    }

    static let mutedKey = "onboardingMuted"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private let queue = DispatchQueue(label: "app.cleen.onboarding.sound", qos: .userInitiated)
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]

    var isMuted = UserDefaults.standard.bool(forKey: OnboardingSound.mutedKey) {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Self.mutedKey)
            if isMuted { queue.async { self.player.stop() } }
        }
    }

    init() {
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 38
        engine.attach(player)
        engine.attach(reverb)
        engine.connect(player, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
    }

    /// Renders every cue and starts the engine ahead of time, so the first sound plays
    /// on cue.
    func prepare() {
        queue.async {
            for cue in [Cue.shimmer, .tick, .success, .fanfare] where self.buffers[cue] == nil {
                self.buffers[cue] = self.render(cue)
            }
            if !self.engine.isRunning { try? self.engine.start() }
        }
    }

    func play(_ cue: Cue) {
        guard !isMuted else { return }
        queue.async {
            if !self.engine.isRunning {
                do { try self.engine.start() } catch { return }
            }
            let buffer = self.buffers[cue] ?? self.render(cue)
            self.buffers[cue] = buffer
            self.player.scheduleBuffer(buffer, at: nil, options: [])
            if !self.player.isPlaying { self.player.play() }
        }
    }

    func stop() {
        queue.async {
            self.player.stop()
            self.engine.stop()
        }
    }

    // MARK: Synthesis

    /// One struck note: when it starts, its pitch, how loud, and how long it rings.
    private struct Note {
        let start: Double
        let frequency: Double
        let gain: Double
        let decay: Double
        var attack = 0.006
    }

    private func notes(for cue: Cue) -> [Note] {
        switch cue {
        case .shimmer:
            // D major add 9, rolled upward over a low pad.
            [587.33, 739.99, 880.0, 1108.73, 1318.51].enumerated().map { index, frequency in
                Note(start: 0.12 + Double(index) * 0.085, frequency: frequency, gain: 0.16, decay: 1.6)
            } + [
                Note(start: 0, frequency: 146.83, gain: 0.12, decay: 2.8, attack: 0.5),
                Note(start: 0, frequency: 220.0, gain: 0.08, decay: 2.8, attack: 0.6),
            ]
        case .tick:
            [Note(start: 0, frequency: 1760, gain: 0.05, decay: 0.07), Note(start: 0.012, frequency: 2637, gain: 0.025, decay: 0.05)]
        case .success:
            [Note(start: 0, frequency: 880, gain: 0.1, decay: 0.5), Note(start: 0.09, frequency: 1318.51, gain: 0.1, decay: 0.8)]
        case .fanfare:
            [293.66, 440.0, 587.33, 739.99, 880.0, 1174.66].enumerated().map { index, frequency in
                Note(start: Double(index) * 0.11, frequency: frequency, gain: 0.14, decay: 2.2)
            } + [Note(start: 0, frequency: 146.83, gain: 0.12, decay: 3.2, attack: 0.4)]
        }
    }

    private func render(_ cue: Cue) -> AVAudioPCMBuffer {
        let notes = notes(for: cue)
        let rate = format.sampleRate
        let length = (notes.map { $0.start + $0.decay * 4 }.max() ?? 1) + 0.2
        let frames = AVAudioFrameCount(length * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        for frame in 0..<Int(frames) {
            left[frame] = 0
            right[frame] = 0
        }
        for (index, note) in notes.enumerated() {
            // Spread the notes a little across the stereo field.
            let pan = notes.count > 1 ? Double(index) / Double(notes.count - 1) * 0.6 - 0.3 : 0
            let first = Int(note.start * rate)
            let count = Int(note.decay * 4 * rate)
            for offset in 0..<count where first + offset < Int(frames) {
                let t = Double(offset) / rate
                let envelope = min(t / note.attack, 1) * exp(-t / note.decay)
                // A bell: the fundamental, a soft octave, and a faint inharmonic partial.
                let phase = 2 * Double.pi * note.frequency * t
                let tone = sin(phase) + 0.18 * sin(2 * phase) * exp(-t / (note.decay * 0.4)) + 0.06 * sin(2.76 * phase) * exp(-t / (note.decay * 0.25))
                let sample = tone * envelope * note.gain
                left[first + offset] += Float(sample * (1 - pan))
                right[first + offset] += Float(sample * (1 + pan))
            }
        }
        return buffer
    }
}
