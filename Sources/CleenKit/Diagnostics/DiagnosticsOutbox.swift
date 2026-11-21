import Foundation

/// Reports waiting to be sent, one file each, so they survive a quit, a crash or a Mac
/// without network. Bounded on both ends: the oldest go when there are more than
/// `maxCount`, and any older than `maxAge` are dropped unsent.
public struct DiagnosticsOutbox: Sendable {
    public let folder: URL
    public let maxCount: Int
    public let maxAge: TimeInterval

    public init(folder: URL, maxCount: Int = 50, maxAge: TimeInterval = 14 * 86_400) {
        self.folder = folder
        self.maxCount = maxCount
        self.maxAge = maxAge
    }

    public func add(_ report: DiagnosticReport) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try DiagnosticReport.encoder.encode(report)
        // Sortable by when it happened, unique by id.
        let stamp = Int(report.occurredAt.timeIntervalSince1970 * 1000)
        try data.write(to: folder.appending(path: "\(stamp)-\(report.id.uuidString).json"), options: .atomic)
        files().dropLast(maxCount).forEach(remove)
    }

    /// What's waiting, oldest first. Unreadable or expired files are removed on the way.
    public func pending(now: Date = .now) -> [(url: URL, report: DiagnosticReport)] {
        files().compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let report = try? DiagnosticReport.decoder.decode(DiagnosticReport.self, from: data),
                  now.timeIntervalSince(report.occurredAt) <= maxAge
            else {
                remove(url)
                return nil
            }
            return (url, report)
        }
    }

    public func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Sending was turned off: what was waiting doesn't go either.
    public func clear() {
        files().forEach(remove)
    }

    /// Oldest first: the names start with the time.
    private func files() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

/// Sends what's in the outbox, one report per request.
public struct DiagnosticsUploader: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public enum Outcome: Equatable, Sendable {
        /// The server has it.
        case delivered
        /// The server won't ever take it (malformed, too big): drop it.
        case rejected
        /// Offline, the server busy or down: keep it for later.
        case retryLater
    }

    public let endpoint: URL
    public let userAgent: String
    private let transport: Transport

    public init(endpoint: URL, userAgent: String, transport: @escaping Transport) {
        self.endpoint = endpoint
        self.userAgent = userAgent
        self.transport = transport
    }

    /// No cookies, no cache, nothing kept between requests.
    public static func session() -> Transport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        return { request in try await session.data(for: request) }
    }

    public func send(_ report: DiagnosticReport) async -> Outcome {
        guard let body = try? DiagnosticReport.encoder.encode(report) else { return .rejected }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (_, response) = try? await transport(request), let http = response as? HTTPURLResponse else { return .retryLater }
        return Self.outcome(status: http.statusCode)
    }

    static func outcome(status: Int) -> Outcome {
        switch status {
        case 200..<300: .delivered
        // 404: the server isn't taking reports yet (an app out before its server).
        case 404, 408, 425, 429, 500..<600: .retryLater
        default: .rejected
        }
    }

    /// Sends the outbox oldest first; stops at the first "later" so a server that's down
    /// isn't asked again for every report.
    @discardableResult
    @concurrent public func flush(_ outbox: DiagnosticsOutbox) async -> (delivered: Int, kept: Int) {
        let pending = outbox.pending()
        var delivered = 0
        for (index, entry) in pending.enumerated() {
            switch await send(entry.report) {
            case .delivered:
                outbox.remove(entry.url)
                delivered += 1
            case .rejected:
                outbox.remove(entry.url)
            case .retryLater:
                return (delivered, pending.count - index)
            }
        }
        return (delivered, 0)
    }
}
