import Foundation

/// How fast the teleprompter reads, in words per minute, and the sizes its text comes in.
public enum TeleprompterPace {
    public static let slow = 110
    public static let normal = 140
    public static let fast = 170
    public static let presets = [slow, normal, fast]
    /// Below 60 a script crawls; past 260 nobody keeps up out loud.
    public static let range = 60...260
    public static let step = 10

    public static let fontSizes = 20.0...28.0
    public static let fontStep = 2.0
    public static let defaultFontSize = 24.0

    public static func clamped(_ wordsPerMinute: Int) -> Int {
        min(max(wordsPerMinute, range.lowerBound), range.upperBound)
    }

    /// Moves `steps` notches along the 10-word grid, landing back on it from an odd value.
    public static func stepped(_ wordsPerMinute: Int, by steps: Int) -> Int {
        guard steps != 0 else { return clamped(wordsPerMinute) }
        let snapped = steps > 0
            ? Int((Double(wordsPerMinute) / Double(step)).rounded(.down)) * step
            : Int((Double(wordsPerMinute) / Double(step)).rounded(.up)) * step
        return clamped(snapped + steps * step)
    }

    public static func clampedFont(_ size: Double) -> Double {
        min(max(size, fontSizes.lowerBound), fontSizes.upperBound)
    }

    /// Words as a person reads them aloud: runs of letters or digits, so punctuation and
    /// stray symbols don't count.
    public static func wordCount(_ text: String) -> Int {
        var count = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            let isWordScalar = CharacterSet.alphanumerics.contains(scalar)
            if isWordScalar, !inWord { count += 1 }
            inWord = isWordScalar
        }
        return count
    }

    /// Seconds to read `words` at the pace, out loud.
    public static func readingTime(words: Int, wordsPerMinute: Int) -> TimeInterval {
        guard words > 0 else { return 0 }
        return Double(words) / Double(clamped(wordsPerMinute)) * 60
    }

    /// The share of the script that goes by per second. The scroll is paced by words, not
    /// points, so it reads the same at every font size and panel width.
    public static func progressPerSecond(words: Int, wordsPerMinute: Int) -> Double {
        let seconds = readingTime(words: words, wordsPerMinute: wordsPerMinute)
        return seconds > 0 ? 1 / seconds : 0
    }
}

/// Where the script is, as a share from 0 (first line under the camera) to 1 (last line
/// under it). Kept as an anchor and a rate instead of a running offset, so any frame can
/// ask for the exact position at its own timestamp and the scroll never stutters.
public struct TeleprompterClock: Equatable, Sendable {
    public private(set) var anchorProgress = 0.0
    public private(set) var anchorTime: TimeInterval = 0
    public private(set) var isRunning = false
    /// Share of the script per second.
    public private(set) var rate: Double

    public init(rate: Double = 0) {
        self.rate = max(0, rate)
    }

    public func progress(at time: TimeInterval) -> Double {
        guard isRunning else { return anchorProgress }
        return min(1, max(0, anchorProgress + (time - anchorTime) * rate))
    }

    public func isFinished(at time: TimeInterval) -> Bool {
        progress(at: time) >= 1
    }

    /// Seconds until the last line reaches the camera, if it's moving.
    public func remaining(at time: TimeInterval) -> TimeInterval? {
        guard isRunning, rate > 0 else { return nil }
        return (1 - progress(at: time)) / rate
    }

    public mutating func start(at time: TimeInterval) {
        guard !isRunning else { return }
        anchorTime = time
        isRunning = true
    }

    public mutating func pause(at time: TimeInterval) {
        guard isRunning else { return }
        anchorProgress = progress(at: time)
        anchorTime = time
        isRunning = false
    }

    /// A new pace takes over from where the text is now, without a jump.
    public mutating func setRate(_ rate: Double, at time: TimeInterval) {
        anchorProgress = progress(at: time)
        anchorTime = time
        self.rate = max(0, rate)
    }

    public mutating func reset() {
        anchorProgress = 0
        isRunning = false
    }
}
