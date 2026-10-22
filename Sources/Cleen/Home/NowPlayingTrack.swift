import Foundation

/// One Now Playing reading from the system, whichever app is playing.
nonisolated struct NowPlayingTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    /// Playhead at `timestamp`.
    let elapsed: TimeInterval
    let timestamp: Date
    let isPlaying: Bool
    let pid: Int32
    let artworkKey: String?

    /// Same item, regardless of where the playhead is.
    var identity: String { "\(pid)|\(title)|\(artist)|\(album)" }

    init?(json: [String: Any]) {
        guard let title = json["title"] as? String, !title.isEmpty else { return nil }
        self.title = title
        artist = json["artist"] as? String ?? ""
        album = json["album"] as? String ?? ""
        duration = json["duration"] as? Double ?? 0
        elapsed = json["elapsed"] as? Double ?? 0
        timestamp = (json["timestamp"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .now
        let rate = json["rate"] as? Double ?? 0
        isPlaying = (json["playing"] as? Bool ?? false) || rate > 0
        pid = Int32(json["pid"] as? Int ?? 0)
        artworkKey = json["artworkKey"] as? String
    }

    func position(at date: Date) -> TimeInterval {
        let moved = isPlaying ? max(0, date.timeIntervalSince(timestamp)) : 0
        return duration > 0 ? min(duration, elapsed + moved) : elapsed + moved
    }
}
