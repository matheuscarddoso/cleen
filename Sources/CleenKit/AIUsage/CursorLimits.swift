import Foundation
import SQLite3

/// Cursor's plan usage for the billing cycle, read with the Cursor app's own sign-in.
///
/// The access token lives in the editor's state database (`cursorAuth/accessToken` in
/// `state.vscdb`), opened read-only. The usage call is the one Cursor's dashboard makes
/// (`DashboardService/GetCurrentPeriodUsage` on api2.cursor.sh) and isn't documented, so a
/// changed response just hides the row. An expired token is never refreshed here: Cursor
/// renews it itself the next time it opens.
public enum CursorLimits {
    static let usageURL = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!

    static func database(home: URL) -> URL {
        home.appending(path: "Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    public static func fetch(home: URL = Paths.home) async -> ProviderLimits? {
        let database = database(home: home)
        guard LimitsSupport.exists(database),
              let token = await BlockingIO.run({ readToken(database: database) })
        else { return nil }
        if let expiry = LimitsSupport.jwtExpiry(token), expiry < .now {
            return ProviderLimits(provider: .cursor, state: .signInAgain)
        }

        var request = URLRequest(url: usageURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = Data("{}".utf8)
        switch await LimitsSupport.send(request) {
        case .ok(let data):
            guard let windows = parseUsage(data), !windows.isEmpty else { return nil }
            return ProviderLimits(provider: .cursor, state: .windows(windows))
        case .unauthorized:
            return ProviderLimits(provider: .cursor, state: .signInAgain)
        case .failed:
            return nil
        }
    }

    /// The stored access token, from a read-only connection (Cursor may be writing to the
    /// database at the same time; WAL lets both proceed).
    static func readToken(database: URL) -> String? {
        var db: OpaquePointer?
        defer { sqlite3_close_v2(db) }
        guard sqlite3_open_v2(database.path(percentEncoded: false), &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return nil }
        sqlite3_busy_timeout(db, 1000)

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_blob(statement, 0)
        else { return nil }
        let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        let token = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return token.isEmpty ? nil : token
    }

    /// `{"billingCycleStart":"…ms","billingCycleEnd":"…ms","planUsage":{"totalPercentUsed":26.3,
    /// "totalSpend":…,"limit":…},"enabled":true}`. The percentage Cursor computes wins;
    /// older accounts only report spend against the included amount (both in cents).
    static func parseUsage(_ data: Data) -> [UsageWindow]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["enabled"] as? Bool != false,
              let plan = object["planUsage"] as? [String: Any]
        else { return nil }

        let percent: Double
        if let total = LimitsSupport.number(plan["totalPercentUsed"]) {
            percent = total
        } else if let limit = LimitsSupport.number(plan["limit"]), limit > 0 {
            let spent = LimitsSupport.number(plan["totalSpend"])
                ?? (limit - (LimitsSupport.number(plan["remaining"]) ?? limit))
            percent = spent / limit * 100
        } else {
            return nil
        }

        let start = LimitsSupport.number(object["billingCycleStart"]).map { Date(timeIntervalSince1970: $0 / 1000) }
        let end = LimitsSupport.number(object["billingCycleEnd"]).map { Date(timeIntervalSince1970: $0 / 1000) }
        let length = if let start, let end, end > start { end.timeIntervalSince(start) } else { 30 * 86_400.0 }
        return [UsageWindow(name: String(localized: "Mensal"), used: max(percent, 0) / 100, resetsAt: end, length: length)]
    }
}
