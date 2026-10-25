import Foundation
import os

/// Claude subscription limits (the session and weekly windows Claude Code shows), read
/// with Claude Code's own sign-in: from the Keychain, or from the file Claude Code
/// writes instead when it can't use the Keychain.
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
        /// Claude Code has no sign-in stored on this Mac.
        case noCredential
        /// There is one, but the Keychain prompt was turned down (or closed).
        case keychainDenied
        case expired
        case unavailable
    }

    /// What went wrong, for Console: never a token, only which step failed.
    static let log = Logger(subsystem: "app.cleen.Cleen", category: "limits")

    public static func fetch(home: URL = Paths.home) async -> Result<Report, Failure> {
        let (credentials, denied) = await readCredentials(home: home)
        guard !credentials.isEmpty else {
            log.info("no Claude sign-in read (keychain denied: \(denied))")
            return .failure(denied ? .keychainDenied : .noCredential)
        }
        // The sign-in Claude Code renewed last; an expired one only if that's all there is.
        guard let credential = credentials.first(where: { $0.expiresAt.map { $0 > .now } ?? true }) else {
            log.info("every Claude sign-in found has expired (\(credentials.count))")
            return .failure(.expired)
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else {
            log.info("limits request didn't go through")
            return .failure(.unavailable)
        }
        if status == 401 { return .failure(.expired) }
        guard status == 200, let windows = parseWindows(data), !windows.isEmpty else {
            log.info("limits answered \(status) without windows")
            return .failure(.unavailable)
        }
        return .success(Report(plan: credential.plan, windows: windows))
    }

    struct Credential {
        let accessToken: String
        let expiresAt: Date?
        let plan: String?
    }

    static let service = "Claude Code-credentials"

    /// Claude Code's stored sign-ins, the latest expiry first, and whether the Keychain
    /// turned a read down. Besides the usual item, a Claude Code run with its own config
    /// folder (`CLAUDE_CONFIG_DIR`) keeps one named `Claude Code-credentials-<hash>`;
    /// without the Keychain, Claude Code writes `~/.claude/.credentials.json` instead.
    static func readCredentials(home: URL) async -> (credentials: [Credential], denied: Bool) {
        var services = [service]
        services += await keychainServices().filter { $0.hasPrefix(service + "-") }
        var found: [Credential] = []
        var denied = false
        for name in services {
            switch await readKeychain(service: name) {
            case .found(let credential): found.append(credential)
            case .denied: denied = true
            case .missing: break
            }
        }
        if let credential = await readCredentialsFile(home: home) { found.append(credential) }
        return (found.sorted { ($0.expiresAt ?? .distantFuture) > ($1.expiresAt ?? .distantFuture) }, denied)
    }

    /// `~/.claude/.credentials.json`, which Claude Code writes when it can't use the
    /// Keychain; same shape as the Keychain item.
    static func readCredentialsFile(home: URL) async -> Credential? {
        let file = home.appending(path: ".claude/.credentials.json")
        guard let data = await BlockingIO.run({ try? Data(contentsOf: file) }) else { return nil }
        return parseCredential(data)
    }

    enum KeychainRead {
        case found(Credential)
        case missing
        /// The item is there, but the prompt was turned down or closed.
        case denied
    }

    /// Asks the `security` tool (so the Keychain prompt's "Always Allow" survives Cleen
    /// updates) for one stored sign-in. Exit status 44 is "no such item"; any other
    /// failure means it's there and wasn't handed over.
    static func readKeychain(service: String) async -> KeychainRead {
        guard let result = try? await Shell.run("/usr/bin/security", ["find-generic-password", "-s", service, "-w"]) else { return .missing }
        guard result.succeeded else {
            if result.status == 44 { return .missing }
            log.info("keychain read of a Claude item failed with status \(result.status)")
            return .denied
        }
        guard let data = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let credential = parseCredential(data)
        else {
            log.info("a Claude keychain item didn't hold a sign-in Cleen can read")
            return .missing
        }
        return .found(credential)
    }

    /// The names of the generic passwords in the login keychain: only the attributes,
    /// which reading doesn't need permission for (no secret is read here).
    static func keychainServices() async -> [String] {
        guard let result = try? await Shell.run("/usr/bin/security", ["dump-keychain"], timeout: .seconds(10)), result.succeeded else { return [] }
        return services(inDump: result.stdout)
    }

    /// `    "svce"<blob>="Claude Code-credentials-ab12"` → `Claude Code-credentials-ab12`.
    static func services(inDump dump: String) -> [String] {
        var names: [String] = []
        for line in dump.split(whereSeparator: \.isNewline) {
            guard let match = line.firstMatch(of: /"svce"<blob>="(.*)"/) else { continue }
            let name = String(match.1)
            if !names.contains(name) { names.append(name) }
        }
        return names
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
        let names = ["five_hour": String(localized: "Sessão"), "seven_day": String(localized: "Semanal"), "seven_day_opus": String(localized: "Opus semanal"), "seven_day_sonnet": String(localized: "Sonnet semanal")]
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
