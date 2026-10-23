import Foundation
import SQLite3
import Testing
@testable import CleenKit

struct AIProviderLimitsTests {
    /// An unsigned JWT that only carries an expiry, like the ones the tools store.
    private func jwt(expiresIn seconds: TimeInterval) -> String {
        let claims = #"{"sub":"auth0|user_01","exp":\#(Int(Date.now.timeIntervalSince1970 + seconds))}"#
        let payload = Data(claims.utf8).base64EncodedString()
            .replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.\(payload).c2lnbmF0dXJl"
    }

    // MARK: Nothing installed

    @Test func providersThatArentSetUpStayOutWithoutTouchingTheNetwork() async throws {
        let sandbox = try Sandbox()
        #expect(await ProviderLimits.fetchAll(home: sandbox.root).isEmpty)
    }

    // MARK: Cursor

    private func cursorDatabase(in sandbox: Sandbox, token: String?) throws -> URL {
        let url = CursorLimits.database(home: sandbox.root)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        #expect(sqlite3_open(url.path(percentEncoded: false), &db) == SQLITE_OK)
        // The schema VS Code (and so Cursor) uses for its global state.
        var sql = "CREATE TABLE ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB); INSERT INTO ItemTable VALUES ('cursorAuth/cachedEmail', 'a@b.c');"
        if let token { sql += "INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', '\(token)');" }
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        return url
    }

    @Test func cursorTokenIsReadFromTheStateDatabase() throws {
        let sandbox = try Sandbox()
        let token = jwt(expiresIn: 3600)
        let url = try cursorDatabase(in: sandbox, token: token)
        #expect(CursorLimits.readToken(database: url) == token)
    }

    @Test func cursorSignedOutHasNoToken() throws {
        let sandbox = try Sandbox()
        let url = try cursorDatabase(in: sandbox, token: nil)
        #expect(CursorLimits.readToken(database: url) == nil)
    }

    @Test func cursorExpiredTokenAsksToOpenCursorInsteadOfRefreshing() async throws {
        let sandbox = try Sandbox()
        _ = try cursorDatabase(in: sandbox, token: jwt(expiresIn: -60))
        let limits = await CursorLimits.fetch(home: sandbox.root)
        #expect(limits == ProviderLimits(provider: .cursor, state: .signInAgain))
    }

    @Test func cursorUsesItsOwnPercentage() throws {
        let json = """
        {"billingCycleStart":"1781438541000","billingCycleEnd":"1784030541000","planUsage":{"totalSpend":1200,"includedSpend":1200,"remaining":800,"limit":2000,"autoPercentUsed":10,"apiPercentUsed":30,"totalPercentUsed":26.5},"enabled":true}
        """
        let window = try #require(CursorLimits.parseUsage(Data(json.utf8))?.first)
        #expect(window.used == 0.265)
        #expect(window.resetsAt == Date(timeIntervalSince1970: 1_784_030_541))
        #expect(window.length == 30 * 86_400)
    }

    @Test func cursorFallsBackToSpendAgainstTheIncludedAmount() throws {
        let json = #"{"billingCycleEnd":1784030541000,"planUsage":{"totalSpend":500,"limit":2000}}"#
        let window = try #require(CursorLimits.parseUsage(Data(json.utf8))?.first)
        #expect(window.used == 0.25)
    }

    @Test func cursorWithoutAPlanHasNothingToShow() {
        #expect(CursorLimits.parseUsage(Data(#"{"enabled":false,"planUsage":{"totalPercentUsed":5}}"#.utf8)) == nil)
        #expect(CursorLimits.parseUsage(Data(#"{"planUsage":{}}"#.utf8)) == nil)
    }

    // MARK: Copilot

    /// The shape `copilot_internal/user` returns today for a paid individual plan.
    private let copilotResponse = """
    {"login":"someone","copilot_plan":"individual","quota_reset_date":"2026-11-01","quota_reset_date_utc":"2026-11-01T00:00:00.000Z","token_based_billing":true,
     "quota_snapshots":{
      "chat":{"entitlement":0,"remaining":0,"percent_remaining":100.0,"unlimited":true,"quota_id":"chat"},
      "completions":{"entitlement":0,"remaining":0,"percent_remaining":100.0,"unlimited":true,"quota_id":"completions"},
      "premium_interactions":{"entitlement":200,"remaining":150,"percent_remaining":75.0,"unlimited":false,"overage_permitted":false,"quota_id":"premium_interactions"}}}
    """

    @Test func copilotShowsTheCreditsAndSkipsUnlimitedBuckets() throws {
        let windows = try #require(CopilotLimits.parse(Data(copilotResponse.utf8)))
        #expect(windows.map(\.name) == ["Créditos"])
        #expect(windows[0].used == 0.25)
        #expect(windows[0].resetsAt == (try Date("2026-11-01T00:00:00Z", strategy: .iso8601)))
        #expect(windows[0].length == 31 * 86_400)
    }

    @Test func copilotFreePlanShowsChatAndCompletions() throws {
        let json = """
        {"copilot_plan":"free","limited_user_reset_date":"2026-11-05","quota_snapshots":{
         "premium_interactions":{"entitlement":0,"remaining":0,"percent_remaining":100},
         "chat":{"entitlement":50,"remaining":40},
         "completions":{"entitlement":2000,"remaining":500,"percent_remaining":25}}}
        """
        let windows = try #require(CopilotLimits.parse(Data(json.utf8)))
        #expect(windows.map(\.name) == ["Chat", "Autocompletar"])
        #expect(abs(windows[0].used - 0.2) < 1e-9)
        #expect(windows[1].used == 0.75)
        #expect(windows[0].resetsAt != nil)
    }

    @Test func copilotLegacyFreeQuotas() throws {
        let json = #"{"limited_user_quotas":{"chat":10,"completions":1000},"monthly_quotas":{"chat":50,"completions":2000}}"#
        let windows = try #require(CopilotLimits.parse(Data(json.utf8)))
        #expect(windows.map(\.used) == [0.8, 0.5])
    }

    @Test func copilotOrganizationSeatHasNothingToFill() throws {
        let json = #"{"copilot_plan":"business","token_based_billing":true,"quota_snapshots":{"premium_interactions":{"entitlement":0,"remaining":0,"percent_remaining":100}}}"#
        #expect(try #require(CopilotLimits.parse(Data(json.utf8))).isEmpty)
    }

    @Test func copilotPluginTokenIsOnlyEverGitHubDotCom() {
        let apps = #"{"ghe.example.com:Iv1.x":{"oauth_token":"gho_enterprise"},"github.com:Iv1.b507a08c87ecfe98":{"user":"someone","oauth_token":"gho_dotcom"}}"#
        #expect(CopilotLimits.pluginToken(Data(apps.utf8)) == "gho_dotcom")
        #expect(CopilotLimits.pluginToken(Data(#"{"ghe.example.com":{"oauth_token":"gho_x"}}"#.utf8)) == nil)
    }

    @Test func copilotCLITokenIsFoundWhereverTheConfigKeepsIt() {
        let config = #"{"banner":"never","logged_in_users":[{"host":"https://github.com","login":"someone"}],"copilot_tokens":{"https://github.com:someone":"gho_abcdefghijklmnop"}}"#
        #expect(CopilotLimits.cliToken(Data(config.utf8)) == "gho_abcdefghijklmnop")
        #expect(CopilotLimits.cliToken(Data(#"{"theme":"dark"}"#.utf8)) == nil)
    }

    @Test func copilotCountsAsInstalledOnlyWithCopilotItself() throws {
        let sandbox = try Sandbox()
        #expect(!CopilotLimits.isInstalled(home: sandbox.root))
        try sandbox.folder(".config/gh")
        #expect(!CopilotLimits.isInstalled(home: sandbox.root))
        try sandbox.folder(".vscode/extensions/github.copilot-chat-0.40.0")
        #expect(CopilotLimits.isInstalled(home: sandbox.root))
    }

    // MARK: Grok

    @Test func grokCredentialAndExpiry() throws {
        let token = jwt(expiresIn: 3600)
        let auth = #"{"https://auth.x.ai::b1a00492-073a-47ea-816f-4c329264a828":{"key":"\#(token)","refresh_token":"r","expires_at":"2026-10-23T20:00:00Z"}}"#
        let credential = try #require(GrokLimits.parseCredential(Data(auth.utf8)))
        #expect(credential.token == token)
        // The token's own expiry wins over the entry's.
        #expect(try #require(credential.expiresAt) > .now)
        #expect(GrokLimits.parseCredential(Data(#"{"x":{"refresh_token":"r"}}"#.utf8)) == nil)
    }

    @Test func grokExpiredSignInAsksToRunTheCLI() async throws {
        let sandbox = try Sandbox()
        let auth = #"{"entry":{"key":"\#(jwt(expiresIn: -60))"}}"#
        try sandbox.folder(".grok")
        try auth.write(to: sandbox.url(".grok/auth.json"), atomically: true, encoding: .utf8)
        #expect(await GrokLimits.fetch(home: sandbox.root) == ProviderLimits(provider: .grok, state: .signInAgain))
    }

    @Test func grokHomeCanBeMoved() {
        let home = URL(filePath: "/Users/someone")
        #expect(GrokLimits.authFile(home: home, environment: [:]).path == "/Users/someone/.grok/auth.json")
        #expect(GrokLimits.authFile(home: home, environment: ["GROK_HOME": "/tmp/grok"]).path == "/tmp/grok/auth.json")
    }

    @Test func grokWeeklyPool() throws {
        let json = """
        {"config":{"creditUsagePercent":42.0,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","start":"2026-10-20T04:01:09.238389+00:00","end":"2026-10-27T04:01:09.238389+00:00"},"onDemandCap":{"val":2500},"isUnifiedBillingUser":true}}
        """
        let window = try #require(GrokLimits.parseBilling(Data(json.utf8))?.first)
        #expect(window.name == "Semanal")
        #expect(window.used == 0.42)
        #expect(window.length == 7 * 86_400)
        #expect(abs(try #require(window.resetsAt).timeIntervalSince(try Date("2026-10-27T04:01:09Z", strategy: .iso8601))) < 1)
    }

    @Test func grokZeroUsageIsLeftOutOfTheResponse() throws {
        let json = #"{"config":{"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","start":"2026-10-20T04:01:09Z","end":"2026-10-27T04:01:09Z"}}}"#
        #expect(try #require(GrokLimits.parseBilling(Data(json.utf8))?.first).used == 0)
    }

    @Test func grokMonthlyLegacyCreditsAreNotALimit() {
        let json = #"{"config":{"creditUsagePercent":10,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_MONTHLY","start":"2026-10-01T00:00:00Z","end":"2026-11-01T00:00:00Z"}}}"#
        #expect(GrokLimits.parseBilling(Data(json.utf8)) == nil)
    }

    // MARK: Shared

    @Test(arguments: ["2026-10-27T04:01:09Z", "2026-10-27T04:01:09.238389+00:00", "2026-10-27T04:01:09.238Z", "2026-10-27T01:01:09-03:00"])
    func isoDatesWithAnyFraction(text: String) throws {
        let date = try #require(LimitsSupport.date(text))
        #expect(abs(date.timeIntervalSince(try Date("2026-10-27T04:01:09Z", strategy: .iso8601))) < 1)
    }

    @Test func numbersFromStringsButNotBooleans() {
        #expect(LimitsSupport.number("1784030541000") == 1_784_030_541_000)
        #expect(LimitsSupport.number(NSNumber(value: 26.5)) == 26.5)
        #expect(LimitsSupport.number(true) == nil)
        #expect(LimitsSupport.number("n/a") == nil)
    }
}
