import Foundation

/// Grok's weekly usage pool, read with the Grok CLI's sign-in (`~/.grok/auth.json`, or
/// `$GROK_HOME/auth.json`).
///
/// The call is the one the CLI itself makes for its billing view
/// (`cli-chat-proxy.grok.com/v1/billing?format=credits`). The CLI renews its token when it
/// runs; Cleen never does, so an expired one asks to run `grok` again.
public enum GrokLimits {
    static let billingURL = URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!

    static func authFile(home: URL, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let custom = environment["GROK_HOME"], !custom.isEmpty {
            return Paths.expand(custom, home: home).appending(path: "auth.json")
        }
        return home.appending(path: ".grok/auth.json")
    }

    public static func fetch(home: URL = Paths.home) async -> ProviderLimits? {
        guard let data = await LimitsSupport.readFile(authFile(home: home)),
              let credential = parseCredential(data)
        else { return nil }
        if let expiry = credential.expiresAt, expiry < .now {
            return ProviderLimits(provider: .grok, state: .signInAgain)
        }

        var request = URLRequest(url: billingURL)
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.setValue("xai-grok-cli", forHTTPHeaderField: "X-XAI-Token-Auth")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch await LimitsSupport.send(request) {
        case .ok(let data):
            guard let windows = parseBilling(data), !windows.isEmpty else { return nil }
            return ProviderLimits(provider: .grok, state: .windows(windows))
        case .unauthorized:
            return ProviderLimits(provider: .grok, state: .signInAgain)
        case .failed:
            return nil
        }
    }

    struct Credential: Equatable {
        let token: String
        let expiresAt: Date?
    }

    /// `{"<issuer>::<client id>": {"key": "<access token>", "expires_at": "…"}}`, one entry
    /// per sign-in; the first one with a token is used.
    static func parseCredential(_ data: Data) -> Credential? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        for key in object.keys.sorted() {
            guard let entry = object[key] as? [String: Any],
                  let token = (entry["key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty
            else { continue }
            let expiry = LimitsSupport.jwtExpiry(token)
                ?? LimitsSupport.date(entry["expires_at"])
                ?? LimitsSupport.date(entry["expires"])
            return Credential(token: token, expiresAt: expiry)
        }
        return nil
    }

    /// `{"config": {"creditUsagePercent": 42.0, "currentPeriod": {"type":
    /// "USAGE_PERIOD_TYPE_WEEKLY", "start": "…", "end": "…"}}}`. Proto-JSON drops zero values,
    /// so a missing percentage is 0%. Only the weekly pool is a limit Grok enforces; an
    /// account still on the old monthly credits has nothing to show.
    static func parseBilling(_ data: Data) -> [UsageWindow]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = object["config"] as? [String: Any],
              let period = config["currentPeriod"] as? [String: Any],
              period["type"] as? String == "USAGE_PERIOD_TYPE_WEEKLY",
              let start = LimitsSupport.date(period["start"]),
              let end = LimitsSupport.date(period["end"]),
              end > start
        else { return nil }
        let percent: Double
        if let raw = config["creditUsagePercent"] {
            guard let value = LimitsSupport.number(raw) else { return nil }
            percent = value
        } else {
            percent = 0
        }
        return [UsageWindow(name: String(localized: "Semanal"), used: max(percent, 0) / 100, resetsAt: end, length: end.timeIntervalSince(start))]
    }
}
