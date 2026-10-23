import Foundation

/// GitHub Copilot's monthly quotas, read from `api.github.com/copilot_internal/user` (the
/// endpoint the Copilot plugins call) with a GitHub token Copilot tooling already left on
/// the Mac.
///
/// Only when Copilot itself is set up here (its editor plugin config, the Copilot CLI's
/// folder, or the VS Code extension): a GitHub CLI login alone doesn't mean anyone uses
/// Copilot. Token sources, prompt-free first: the plugins' `hosts.json`/`apps.json`, the
/// Copilot CLI's plaintext config, then `gh auth token`. The Copilot CLI's own Keychain item
/// is not read: `security` isn't on its access list, so every read would raise a dialog.
public enum CopilotLimits {
    static let usageURL = URL(string: "https://api.github.com/copilot_internal/user")!

    public static func fetch(home: URL = Paths.home) async -> ProviderLimits? {
        guard isInstalled(home: home), let token = await readToken(home: home) else { return nil }

        var request = URLRequest(url: usageURL)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-GitHub-Api-Version")
        switch await LimitsSupport.send(request) {
        case .ok(let data):
            guard let windows = parse(data), !windows.isEmpty else { return nil }
            return ProviderLimits(provider: .copilot, state: .windows(windows))
        case .unauthorized:
            return ProviderLimits(provider: .copilot, state: .signInAgain)
        case .failed:
            return nil
        }
    }

    static func isInstalled(home: URL) -> Bool {
        if LimitsSupport.exists(home.appending(path: ".config/github-copilot")) || LimitsSupport.exists(home.appending(path: ".copilot")) {
            return true
        }
        let extensions = (try? FileManager.default.contentsOfDirectory(atPath: home.appending(path: ".vscode/extensions").path(percentEncoded: false))) ?? []
        return extensions.contains { $0.lowercased().hasPrefix("github.copilot") }
    }

    static func readToken(home: URL) async -> String? {
        let plugin = home.appending(path: ".config/github-copilot")
        for name in ["hosts.json", "apps.json"] {
            if let data = await LimitsSupport.readFile(plugin.appending(path: name)), let token = pluginToken(data) { return token }
        }
        let cli = home.appending(path: ".copilot")
        for name in ["config.json", "settings.json"] {
            if let data = await LimitsSupport.readFile(cli.appending(path: name)), let token = cliToken(data) { return token }
        }
        return await ghToken()
    }

    /// `{"github.com:Iv1.…": {"oauth_token": "gho_…"}}` (or keyed `github.com` in the older
    /// `hosts.json`). Entries for other hosts (GitHub Enterprise) never go to api.github.com.
    static func pluginToken(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object.keys.sorted()
            .filter { $0 == "github.com" || $0.hasPrefix("github.com:") }
            .lazy
            .compactMap { ((object[$0] as? [String: Any])?["oauth_token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    /// The Copilot CLI's config has moved its token between keys across releases, so take
    /// the first value shaped like a GitHub access token instead of guessing key names.
    static func cliToken(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return firstGitHubToken(in: object)
    }

    private static func firstGitHubToken(in value: Any) -> String? {
        switch value {
        case let text as String:
            ["gho_", "ghu_", "ghp_", "github_pat_"].contains { text.hasPrefix($0) && text.count > $0.count + 8 } ? text : nil
        case let array as [Any]:
            array.lazy.compactMap { firstGitHubToken(in: $0) }.first
        case let map as [String: Any]:
            map.keys.sorted().lazy.compactMap { firstGitHubToken(in: map[$0] as Any) }.first
        default:
            nil
        }
    }

    /// The GitHub CLI's login for github.com. `gh` reads its own Keychain item, so this
    /// never prompts; it only prints the token.
    static func ghToken() async -> String? {
        guard let gh = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }),
              let result = try? await Shell.run(gh, ["auth", "token", "--hostname", "github.com"], timeout: .seconds(5)),
              result.succeeded
        else { return nil }
        let token = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty || token.contains(where: \.isWhitespace) ? nil : token
    }

    /// Each `quota_snapshots` bucket reports what's *left*; the rows show what's used.
    /// Unlimited buckets (paid chat and completions) and zero-entitlement placeholders (an
    /// organization-managed seat) have nothing to fill, so they're left out.
    static func parse(_ data: Data) -> [UsageWindow]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let reset = LimitsSupport.date(object["quota_reset_date_utc"])
            ?? LimitsSupport.date(object["quota_reset_date"])
            ?? LimitsSupport.date(object["limited_user_reset_date"])
        let length = monthLength(endingAt: reset)
        let buckets = [
            ("premium_interactions", String(localized: "Créditos")),
            ("chat", String(localized: "Chat")),
            ("completions", String(localized: "Autocompletar")),
        ]

        let snapshots = object["quota_snapshots"] as? [String: Any] ?? [:]
        var windows = buckets.compactMap { key, name -> UsageWindow? in
            guard let used = usedFraction(snapshots[key] as? [String: Any]) else { return nil }
            return UsageWindow(name: name, used: used, resetsAt: reset, length: length)
        }

        // Free accounts from before `quota_snapshots`: what's left against monthly totals.
        if windows.isEmpty, let left = object["limited_user_quotas"] as? [String: Any], let totals = object["monthly_quotas"] as? [String: Any] {
            windows = buckets.dropFirst().compactMap { key, name in
                guard let total = LimitsSupport.number(totals[key]), total > 0,
                      let remaining = LimitsSupport.number(left[key])
                else { return nil }
                return UsageWindow(name: name, used: min(max(1 - remaining / total, 0), 1), resetsAt: reset, length: length)
            }
        }
        return windows
    }

    private static func usedFraction(_ snapshot: [String: Any]?) -> Double? {
        guard let snapshot, snapshot["unlimited"] as? Bool != true else { return nil }
        let entitlement = LimitsSupport.number(snapshot["entitlement"])
        let remaining = LimitsSupport.number(snapshot["remaining"])
        guard entitlement != -1, remaining != -1, entitlement != 0 else { return nil }
        if let percentLeft = LimitsSupport.number(snapshot["percent_remaining"]) {
            return min(max(1 - percentLeft / 100, 0), 1)
        }
        guard let entitlement, entitlement > 0, let remaining else { return nil }
        return min(max(1 - remaining / entitlement, 0), 1)
    }

    /// The quota renews monthly, so the window is the calendar month before the reset.
    private static func monthLength(endingAt reset: Date?) -> TimeInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let reset, let start = calendar.date(byAdding: .month, value: -1, to: reset) else { return 30 * 86_400 }
        return reset.timeIntervalSince(start)
    }
}
