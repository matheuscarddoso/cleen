import Foundation

/// AI tools beyond Claude and Codex whose plan limits Cleen can read with the sign-in the
/// tool itself left on the Mac.
public enum AIProvider: String, Sendable, CaseIterable, Identifiable {
    case cursor
    case copilot
    case grok

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .cursor: "Cursor"
        case .copilot: "Copilot"
        case .grok: "Grok"
        }
    }

    /// A monochrome SF Symbol that reads as the tool at 10 pt.
    public var symbol: String {
        switch self {
        case .cursor: "cursorarrow"
        case .copilot: "airplane"
        case .grok: "slash.circle"
        }
    }
}

/// One provider's limits, or the fact that its sign-in has to be renewed in the tool.
///
/// Every reader is read-only: tokens are never refreshed, stored or logged, and each one
/// only ever goes to its own provider's domain. Anything else that goes wrong (the tool
/// isn't installed, nobody signed in, the endpoint changed) yields no report at all, so
/// the panel simply doesn't show that provider.
public struct ProviderLimits: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable {
        case windows([UsageWindow])
        /// The stored sign-in expired or was rejected; opening the tool renews it.
        case signInAgain
    }

    public let provider: AIProvider
    public let state: State

    public var id: String { provider.id }

    public init(provider: AIProvider, state: State) {
        self.provider = provider
        self.state = state
    }

    /// Every provider found on this Mac, in a stable order.
    public static func fetchAll(home: URL = Paths.home) async -> [ProviderLimits] {
        async let cursor = CursorLimits.fetch(home: home)
        async let copilot = CopilotLimits.fetch(home: home)
        async let grok = GrokLimits.fetch(home: home)
        return await [cursor, copilot, grok].compactMap { $0 }
    }
}

/// The small pieces the provider readers share.
enum LimitsSupport {
    /// No cookies, no cache, no credential storage: nothing a request carries or gets
    /// back outlives it.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration)
    }()

    enum Response {
        case ok(Data)
        case unauthorized
        case failed
    }

    static func send(_ request: URLRequest) async -> Response {
        guard let (data, response) = try? await session.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return .failed }
        switch status {
        case 200..<300: return .ok(data)
        case 401, 403: return .unauthorized
        default: return .failed
        }
    }

    /// A JSON number, or a number sent as a string (proto-JSON writes 64-bit integers so).
    static func number(_ value: Any?) -> Double? {
        let parsed: Double? = switch value {
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): number.doubleValue
        case let text as String: Double(text.trimmingCharacters(in: .whitespaces))
        default: nil
        }
        return parsed.flatMap { $0.isFinite ? $0 : nil }
    }

    /// ISO 8601 with or without fractional seconds (of any length), or a bare UTC day.
    static func date(_ value: Any?) -> Date? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if let date = try? Date(text, strategy: .iso8601) { return date }
        let whole = text.replacing(/\.\d+/, with: "")
        if let date = try? Date(whole, strategy: .iso8601) { return date }
        return try? Date(text, strategy: .iso8601.year().month().day())
    }

    /// The claims of a JWT, read without verifying it: only to know when it expires.
    static func jwtClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacing("-", with: "+").replacing("_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func jwtExpiry(_ token: String) -> Date? {
        jwtClaims(token).flatMap { number($0["exp"]) }.map { Date(timeIntervalSince1970: $0) }
    }

    static func readFile(_ url: URL) async -> Data? {
        await BlockingIO.run { try? Data(contentsOf: url) }
    }

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
