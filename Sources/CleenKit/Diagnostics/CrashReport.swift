import CryptoKit
import Foundation

/// A crash report as macOS writes it (`.ips`, in ~/Library/Logs/DiagnosticReports): one
/// JSON line of metadata, then the report itself as JSON.
///
/// Only crashes (`bug_type` 309) are read; hangs and resource reports come through
/// MetricKit instead. The report keeps every thread and loaded image, which is what
/// symbolicating it later needs, and loses what identifies the Mac (see `sanitizedBody`).
public struct CrashReport: Sendable {
    public struct Frame: Sendable, Equatable {
        public let image: String
        public let symbol: String?
        public let offset: Int
        /// In one of macOS's own libraries, not the app's (or a helper's) code.
        public let isSystem: Bool
    }

    public let process: String
    public let parentProcess: String?
    public let responsibleProcess: String?
    /// The app the process ran on behalf of (`app.cleen.Cleen` for Cleen and its helpers).
    public let coalition: String?
    public let appVersion: String?
    public let appBuild: String?
    public let osVersion: String?
    public let model: String?
    public let capturedAt: Date?
    public let exceptionType: String?
    public let signal: String?
    /// What the kernel said ended it ("Abort trap: 6").
    public let termination: String?
    /// The runtime's own words, when it left any ("abort() called").
    public let reason: String?
    /// The crashed thread, innermost frame first.
    public let frames: [Frame]
    /// The report as JSON, without the keys that identify this Mac.
    public let sanitizedBody: Data

    /// Identifiers of the Mac and its boot, A/B trials and feature flags: none of them
    /// helps reading a crash, all of them could tie reports to one machine.
    static let identifyingKeys: Set<String> = [
        "crashReporterKey", "sleepWakeUUID", "bootSessionUUID", "trialInfo",
        "appleIntelligenceStatus", "logWritingSignature", "vmSummary",
    ]

    /// Runtime plumbing every crash of a kind passes through (raising, aborting): it says
    /// how the process died, not where, so the signature looks past it.
    static let plumbing: Set<String> = [
        "libsystem_kernel.dylib", "libsystem_pthread.dylib", "libsystem_c.dylib",
        "libsystem_platform.dylib", "libc++abi.dylib", "libobjc.A.dylib",
    ]

    public init?(data: Data) {
        guard let newline = data.firstIndex(of: UInt8(ascii: "\n")),
              let header = (try? JSONSerialization.jsonObject(with: data[data.startIndex..<newline])) as? [String: Any],
              Self.string(header["bug_type"]) == "309",
              var body = (try? JSONSerialization.jsonObject(with: data[data.index(after: newline)...])) as? [String: Any],
              let process = body["procName"] as? String ?? header["app_name"] as? String
        else { return nil }

        self.process = process
        parentProcess = body["parentProc"] as? String
        responsibleProcess = body["responsibleProc"] as? String
        coalition = body["coalitionName"] as? String
        appVersion = (header["app_version"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        appBuild = (header["build_version"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        osVersion = header["os_version"] as? String
        model = body["modelCode"] as? String
        capturedAt = (body["captureTime"] as? String).flatMap(Self.date)
        let exception = body["exception"] as? [String: Any]
        exceptionType = exception?["type"] as? String
        signal = exception?["signal"] as? String
        termination = (body["termination"] as? [String: Any])?["indicator"] as? String
        reason = (body["asi"] as? [String: [String]])?.values.lazy.compactMap(\.first).first
        frames = Self.faultingFrames(in: body)

        for key in Self.identifyingKeys { body[key] = nil }
        guard let sanitized = try? JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes, .sortedKeys]) else { return nil }
        sanitizedBody = sanitized
    }

    /// Whether the process is the app or one of its helpers.
    public func belongs(toBundleID bundleID: String, name: String) -> Bool {
        coalition == bundleID || process == name || parentProcess == name || responsibleProcess == name
    }

    /// The frames that tell this crash from another: the crashed thread past the
    /// runtime's plumbing.
    public var tellingFrames: ArraySlice<Frame> {
        let past = frames.drop { Self.plumbing.contains($0.image) }
        return (past.isEmpty ? frames[...] : past).prefix(5)
    }

    /// Same crash, same signature, whichever Mac it happened on: the process, how it
    /// died and where.
    public var signature: String {
        let parts = [process, exceptionType ?? "", signal ?? ""] + tellingFrames.map { "\($0.image):\($0.symbol ?? String($0.offset))" }
        return Self.digest(parts.joined(separator: "|"))
    }

    /// One line for a list: "perl · EXC_CRASH (SIGABRT) · libCleenNowPlaying.dylib Write",
    /// naming the innermost frame of the app's own code when there is one, since that's
    /// where a fix goes.
    public var summary: String {
        let death = [exceptionType, signal.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ")
        let frame = frames.first { !$0.isSystem } ?? tellingFrames.first
        let place = frame.map { [$0.image, $0.symbol].compactMap { $0 }.joined(separator: " ") }
        return [process, death.isEmpty ? nil : death, place].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Reading

    private static func faultingFrames(in body: [String: Any]) -> [Frame] {
        guard let threads = body["threads"] as? [[String: Any]], !threads.isEmpty else { return [] }
        let index = (body["faultingThread"] as? Int).flatMap { threads.indices.contains($0) ? $0 : nil }
            ?? threads.firstIndex { $0["triggered"] as? Bool == true } ?? 0
        let images = body["usedImages"] as? [[String: Any]] ?? []
        let raw = threads[index]["frames"] as? [[String: Any]] ?? []
        return raw.map { frame in
            let image = (frame["imageIndex"] as? Int).flatMap { images.indices.contains($0) ? images[$0] : nil }
            let path = image?["path"] as? String
            let name = image?["name"] as? String ?? path.map { ($0 as NSString).lastPathComponent } ?? "???"
            return Frame(image: name, symbol: frame["symbol"] as? String, offset: frame["imageOffset"] as? Int ?? 0, isSystem: isSystem(path))
        }
    }

    /// The OS's own code lives in the sealed system volume and `/usr`. An image with no
    /// path at all (the shared cache didn't say) counts as the system's too.
    private static func isSystem(_ path: String?) -> Bool {
        guard let path else { return true }
        return ["/System/", "/usr/", "/Library/Apple/"].contains { path.hasPrefix($0) }
    }

    /// "2026-11-16 10:48:34.8721 -0300": the fraction has as many digits as it likes.
    static func date(_ text: String) -> Date? {
        let whole = text.replacing(/\.\d+/, with: "")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: whole)
    }

    private static func string(_ value: Any?) -> String? {
        (value as? String) ?? (value as? Int).map(String.init)
    }

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
