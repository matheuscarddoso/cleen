import Foundation

/// The video call link in a calendar event, wherever the invite put it (the URL field,
/// the location, the notes): Meet, Zoom, Teams, Webex, Whereby, Around, Slack huddles.
public enum MeetingLink {
    public static func find(in texts: [String?]) -> URL? {
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector?.matches(in: text, range: range) ?? [] {
                guard let url = match.url, isMeeting(url) else { continue }
                return url
            }
        }
        return nil
    }

    public static func isMeeting(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "zoommtg" || scheme == "msteams" { return true }
        guard scheme == "https" || scheme == "http", let host = url.host()?.lowercased() else { return false }
        let path = url.path().lowercased()
        if host == "meet.google.com" { return path.count > 1 }
        if host.hasSuffix("zoom.us") || host.hasSuffix("zoom.com") { return path.hasPrefix("/j/") || path.hasPrefix("/my/") || path.hasPrefix("/w/") }
        if host == "teams.microsoft.com" || host == "teams.live.com" { return path.contains("meetup-join") || path.hasPrefix("/meet/") || path.hasPrefix("/l/meet") }
        if host.hasSuffix("webex.com") { return true }
        return ["whereby.com", "around.co", "meet.jit.si", "app.slack.com", "cal.com", "facetime.apple.com"].contains { host == $0 || host.hasSuffix("." + $0) }
            && path.count > 1
    }

    nonisolated(unsafe) private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
}
