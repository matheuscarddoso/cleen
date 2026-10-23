import Foundation

/// Codex CLI writes its rate limits into every session log; the newest one is current.
public enum CodexLimits {
    public static func read(home: URL = Paths.home) -> [UsageWindow]? {
        let sessions = home.appending(path: ".codex/sessions")
        guard let enumerator = FileManager.default.enumerator(at: sessions, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        var newest: (URL, Date)?
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if date > (newest?.1 ?? .distantPast) { newest = (url, date) }
        }
        guard let file = newest?.0, let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline).reversed() where line.contains("rate_limits") {
            if let windows = parse(line: Data(line.utf8), loggedAt: newest?.1 ?? .now) { return windows }
        }
        return nil
    }

    static func parse(line: Data, loggedAt: Date) -> [UsageWindow]? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
        let payload = object["payload"] as? [String: Any] ?? object
        guard let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        return [("primary", String(localized: "Sessão")), ("secondary", String(localized: "Semanal"))].compactMap { key, name in
            guard let window = limits[key] as? [String: Any],
                  let percent = (window["used_percent"] as? NSNumber)?.doubleValue
            else { return nil }
            let minutes = (window["window_minutes"] as? NSNumber)?.doubleValue ?? (key == "primary" ? 300 : 10_080)
            let reset: Date? = if let seconds = (window["resets_in_seconds"] as? NSNumber)?.doubleValue {
                loggedAt.addingTimeInterval(seconds)
            } else if let epoch = (window["resets_at"] as? NSNumber)?.doubleValue {
                Date(timeIntervalSince1970: epoch)
            } else {
                nil
            }
            return UsageWindow(name: name, used: percent / 100, resetsAt: reset, length: minutes * 60)
        }
    }
}
