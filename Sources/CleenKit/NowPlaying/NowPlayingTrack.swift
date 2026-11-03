import Foundation

/// One Now Playing reading from the system, whichever app is playing.
public struct NowPlayingTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    /// Playhead at `timestamp`.
    public let elapsed: TimeInterval
    public let timestamp: Date
    public let isPlaying: Bool
    /// Speed the playhead moves at while playing (1, or 1.5 for a sped-up podcast).
    public let rate: Double
    public let pid: Int32
    public let artworkKey: String?

    /// Same item, regardless of where the playhead is.
    public var identity: String { "\(pid)|\(title)|\(artist)|\(album)" }

    public init(
        title: String, artist: String = "", album: String = "", duration: TimeInterval = 0, elapsed: TimeInterval = 0,
        timestamp: Date = .now, isPlaying: Bool, rate: Double = 1, pid: Int32, artworkKey: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsed = elapsed
        self.timestamp = timestamp
        self.isPlaying = isPlaying
        self.rate = rate
        self.pid = pid
        self.artworkKey = artworkKey
    }

    /// A line from the helper (see Support/NowPlaying/CleenNowPlaying.m); nil when
    /// nothing is playing.
    public init?(json: [String: Any]) {
        guard let title = json["title"] as? String, !title.isEmpty else { return nil }
        self.title = title
        artist = json["artist"] as? String ?? ""
        album = json["album"] as? String ?? ""
        duration = json["duration"] as? Double ?? 0
        elapsed = json["elapsed"] as? Double ?? 0
        timestamp = (json["timestamp"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .now
        // The app's own playing flag is the answer. The info's playback rate is a
        // snapshot that browsers and some players leave at 1 after pausing, so it only
        // moves the playhead; it never turns a paused app into a playing one.
        isPlaying = json["playing"] as? Bool ?? false
        rate = json["rate"] as? Double ?? 1
        pid = Int32(json["pid"] as? Int ?? 0)
        artworkKey = json["artworkKey"] as? String
    }

    public func position(at date: Date) -> TimeInterval {
        let speed = rate > 0 ? rate : 1
        let moved = isPlaying ? max(0, date.timeIntervalSince(timestamp)) * speed : 0
        return duration > 0 ? min(duration, elapsed + moved) : elapsed + moved
    }

    /// The same item, playing or not as of `date`, with the playhead carried over so it
    /// neither jumps nor keeps running.
    public func playing(_ isPlaying: Bool, at date: Date) -> NowPlayingTrack {
        guard isPlaying != self.isPlaying else { return self }
        return NowPlayingTrack(
            title: title, artist: artist, album: album, duration: duration, elapsed: position(at: date),
            timestamp: date, isPlaying: isPlaying, rate: rate, pid: pid, artworkKey: artworkKey
        )
    }
}
