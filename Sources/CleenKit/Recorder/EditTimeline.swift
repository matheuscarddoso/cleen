import Foundation

/// A slice of the recording kept in the edit, Screen Studio's clips: split with the
/// scissors, removed, or played faster.
public struct ClipSegment: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// Seconds of the recording.
    public var start: Double
    public var end: Double
    /// 1 is real time; 2 plays twice as fast.
    public var speed: Double

    public init(id: UUID = UUID(), start: Double, end: Double, speed: Double = 1) {
        self.id = id
        self.start = start
        self.end = end
        self.speed = speed
    }

    /// How long it lasts in the finished video.
    public var duration: Double { max(0, end - start) / max(0.1, speed) }
}

/// The finished video's clock against the recording's: clips play one after the other,
/// each at its own speed. The timeline, the player and the export all count in output
/// seconds; the cursor, the clicks and the zooms live in recording seconds.
public struct EditTimeline: Sendable, Equatable {
    public let clips: [ClipSegment]

    public init(clips: [ClipSegment]) {
        self.clips = clips
    }

    public var duration: Double { clips.reduce(0) { $0 + $1.duration } }

    /// Where each clip starts in the finished video.
    public var starts: [Double] {
        var at = 0.0
        return clips.map { clip in
            defer { at += clip.duration }
            return at
        }
    }

    /// The recording's second shown at `output`.
    public func sourceTime(at output: Double) -> Double {
        var at = 0.0
        for clip in clips {
            if output <= at + clip.duration {
                return clip.start + max(0, output - at) * clip.speed
            }
            at += clip.duration
        }
        return clips.last?.end ?? output
    }

    /// When the recording's second `source` shows in the finished video. A moment that
    /// was cut away maps to where the cut is.
    public func outputTime(at source: Double) -> Double {
        var at = 0.0
        for clip in clips {
            if source < clip.start { return at }
            if source <= clip.end { return at + (source - clip.start) / clip.speed }
            at += clip.duration
        }
        return at
    }

    /// The clip playing at `output`, by index.
    public func clipIndex(at output: Double) -> Int? {
        var at = 0.0
        for (index, clip) in clips.enumerated() {
            if output < at + clip.duration { return index }
            at += clip.duration
        }
        return clips.isEmpty ? nil : clips.count - 1
    }

    /// The clips with the one at `output` cut in two there. Nothing changes too close to
    /// a clip's edge to leave a usable piece.
    public func splitting(at output: Double, minimum: Double = 0.1) -> [ClipSegment] {
        guard let index = clipIndex(at: output) else { return clips }
        let clip = clips[index]
        let cut = sourceTime(at: output)
        guard cut - clip.start >= minimum, clip.end - cut >= minimum else { return clips }
        var result = clips
        result[index].end = cut
        result.insert(ClipSegment(start: cut, end: clip.end, speed: clip.speed), at: index + 1)
        return result
    }
}
