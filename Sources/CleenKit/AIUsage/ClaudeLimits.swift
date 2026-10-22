import Foundation

/// Claude subscription limits (the session and weekly windows Claude Code shows), read
/// with Claude Code's own sign-in from the Keychain.
///
/// The endpoint is the one Claude Code itself calls and isn't publicly documented, so
/// every step degrades quietly: no credential, an expired one, or a changed response
/// just means the panel shows local usage only. The token is never stored or logged,
/// and only ever sent to api.anthropic.com.
public enum ClaudeLimits {
    public struct Report: Sendable, Equatable {
        public let plan: String?
        public let windows: [UsageWindow]
    }

    public enum Failure: Error, Equatable {
        case noCredential
        case expired
        case unavailable
    }

    public static func fetch() async -> Result<Report, Failure> {
        guard let credential = await readCredential() else { return .failure(.noCredential) }
        if let expiry = credential.expiresAt, expiry < .now { return .failure(.expired) }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return .failure(.unavailable) }
        if status == 401 { return .failure(.expired) }
        guard status == 200, let windows = parseWindows(data), !windows.isEmpty else { return .failure(.unavailable) }
        return .success(Report(plan: credential.plan, windows: windows))
    }

    struct Credential {
        let accessToken: String
        let expiresAt: Date?
        let plan: String?
    }

    /// Asks the `security` tool (so the Keychain prompt's "Always Allow" survives Cleen
    /// updates) for Claude Code's stored sign-in.
    static func readCredential() async -> Credential? {
        guard let result = try? await Shell.run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"]),
              result.succeeded,
              let data = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
        else { return nil }
        return parseCredential(data)
    }

    static func parseCredential(_ data: Data) -> Credential? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = object["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }
        let expiry = (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        return Credential(accessToken: token, expiresAt: expiry, plan: planName(subscription: oauth["subscriptionType"] as? String, tier: oauth["rateLimitTier"] as? String))
    }

    /// `max` + `default_claude_max_20x` → `Max 20x`.
    static func planName(subscription: String?, tier: String?) -> String? {
        guard let subscription, !subscription.isEmpty else { return nil }
        var name = subscription.prefix(1).uppercased() + subscription.dropFirst()
        if let tier, let match = tier.firstMatch(of: /(\d+)x/) { name += " \(match.1)x" }
        return name
    }

    /// Windows look like `"five_hour": {"utilization": 42.0, "resets_at": "…"}`. Unknown
    /// windows are kept with a readable name so a new one still shows up.
    static func parseWindows(_ data: Data) -> [UsageWindow]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let order = ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet"]
        let names = ["five_hour": "Sessão", "seven_day": "Semanal", "seven_day_opus": "Opus semanal", "seven_day_sonnet": "Sonnet semanal"]
        let lengths: [String: TimeInterval] = ["five_hour": 5 * 3600]
        return object.compactMap { key, value -> (String, UsageWindow)? in
            guard let window = value as? [String: Any],
                  let utilization = (window["utilization"] as? NSNumber)?.doubleValue
            else { return nil }
            let resets = (window["resets_at"] as? String).flatMap { try? Date($0, strategy: .iso8601) }
                ?? (window["resets_at"] as? String).flatMap { try? Date($0, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) }
            let name = names[key] ?? key.replacing("_", with: " ").capitalized
            return (key, UsageWindow(name: name, used: utilization / 100, resetsAt: resets, length: lengths[key] ?? 7 * 86_400))
        }
        .sorted { (order.firstIndex(of: $0.0) ?? 99, $0.0) < (order.firstIndex(of: $1.0) ?? 99, $1.0) }
        .map(\.1)
    }
}
