import Foundation

/// One report as it travels to Cleen's server (`site/app/api/diagnostics`), already
/// scrubbed. The server checks every field against this same shape (`site/lib/diagnostics.ts`).
public struct DiagnosticReport: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// Cleen or one of its helpers crashed (from the system's crash report).
        case crash
        /// The main thread stopped answering (MetricKit).
        case hang
        /// Too much CPU for too long (MetricKit).
        case cpuException = "cpu-exception"
        /// Too much written to disk (MetricKit).
        case diskWrites = "disk-writes"
        /// Something failed that shouldn't have (a recording, an export), reported by the
        /// app itself.
        case error
    }

    public struct App: Codable, Sendable, Equatable {
        public let version: String
        public let build: String

        public init(version: String, build: String) {
            self.version = version
            self.build = build
        }
    }

    public struct System: Codable, Sendable, Equatable {
        public let os: String
        public let model: String

        public init(os: String, model: String) {
            self.os = os
            self.model = model
        }
    }

    public static let schemaVersion = 1

    public let schema: Int
    public let id: UUID
    public let kind: Kind
    /// The same problem has the same signature on every Mac: what the server groups by.
    public let signature: String
    public let summary: String
    public let process: String
    public let occurredAt: Date
    public let app: App
    public let system: System
    /// This install, but only for this signature (see `DiagnosticsIdentity`): the server
    /// can count how many Macs hit one problem, never follow one Mac across problems.
    public let install: String
    /// The app's own log lines leading up to it, oldest first.
    public let breadcrumbs: [String]
    /// The report itself (the crash report's JSON, MetricKit's diagnostic).
    public let report: String

    public init(id: UUID = UUID(), kind: Kind, signature: String, summary: String, process: String, occurredAt: Date,
                app: App, system: System, install: String, breadcrumbs: [String], report: String) {
        schema = Self.schemaVersion
        self.id = id
        self.kind = kind
        self.signature = signature
        self.summary = summary
        self.process = process
        self.occurredAt = occurredAt
        self.app = app
        self.system = system
        self.install = install
        self.breadcrumbs = breadcrumbs
        self.report = report
    }

    /// A signature for a report the app makes itself, from what identifies the problem.
    public static func signature(_ parts: [String]) -> String {
        CrashReport.digest(parts.joined(separator: "|"))
    }

    /// Every text field through `scrubber`: what's queued is what may leave the Mac.
    public func scrubbed(by scrubber: PersonalDataScrubber) -> DiagnosticReport {
        DiagnosticReport(
            id: id, kind: kind, signature: signature, summary: scrubber.scrub(summary), process: scrubber.scrub(process),
            occurredAt: occurredAt, app: app, system: system, install: install,
            breadcrumbs: breadcrumbs.map(scrubber.scrub), report: scrubber.scrub(report)
        )
    }

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// Ties reports of one install together only within a signature.
public struct DiagnosticsIdentity: Sendable {
    /// A random secret made once per install; it never leaves the Mac.
    public let secret: String

    public init(secret: String) {
        self.secret = secret
    }

    /// A different value for every signature, so two reports of different problems
    /// can't be linked to the same Mac.
    public func install(for signature: String) -> String {
        CrashReport.digest(secret + "|" + signature)
    }
}

/// The frames that identify a MetricKit diagnostic: the attributed thread's stack,
/// innermost first, as binary and offset (MetricKit doesn't symbolicate).
public enum MetricKitStack {
    public static func frames(inCallStackTree json: Data, limit: Int = 5) -> [String] {
        guard let tree = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              let stacks = tree["callStacks"] as? [[String: Any]], !stacks.isEmpty
        else { return [] }
        let stack = stacks.first { $0["threadAttributed"] as? Bool == true } ?? stacks[0]
        var frame = (stack["callStackRootFrames"] as? [[String: Any]])?.first
        var frames: [String] = []
        while let current = frame, frames.count < limit {
            let binary = current["binaryName"] as? String ?? "???"
            let offset = current["offsetIntoBinaryTextSegment"] as? Int ?? 0
            frames.append("\(binary)+\(offset)")
            frame = (current["subFrames"] as? [[String: Any]])?.first
        }
        return frames
    }

    public static func signature(kind: DiagnosticReport.Kind, process: String, frames: [String]) -> String {
        CrashReport.digest(([kind.rawValue, process] + frames).joined(separator: "|"))
    }
}
