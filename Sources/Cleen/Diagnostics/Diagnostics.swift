import AppKit
import CleenKit
import Darwin
import MetricKit
import os

/// Finds what goes wrong in Cleen on this Mac and sends it to Cleen's own server
/// (`site/app/api/diagnostics`), scrubbed, to be debugged later:
///
/// - crashes of Cleen and of its helpers (the Now Playing bridge runs in `perl`), from
///   the reports macOS itself writes, read at launch and as they appear;
/// - hangs, and CPU or disk writes far past normal, from MetricKit;
/// - failures the app reports itself (`Diagnostics.error`).
///
/// Every report carries the app's own log lines leading up to it (`BreadcrumbLog`), and
/// goes through `PersonalDataScrubber` before it's queued. Sending is on by default and
/// turns off in Ajustes › Sobre; off, nothing leaves and what was waiting is dropped. The
/// log itself always stays, on this Mac only, in ~/Library/Logs/Cleen.
final class Diagnostics {
    static let shared = Diagnostics()

    static let sendsKey = "diagnosticsSendsReports"
    private static let secretKey = "diagnosticsSecret"
    private static let seenKey = "diagnosticsSeenCrashReports"
    private static let lastScanKey = "diagnosticsLastCrashScan"
    private static let errorsSentKey = "diagnosticsErrorsSent"
    /// `defaults write app.cleen.Cleen diagnosticsEndpoint http://localhost:3000/api/diagnostics`
    /// points a build at a local server.
    private static let endpointKey = "diagnosticsEndpoint"
    static let defaultEndpoint = URL(string: "https://cleen.ocardoso.com/api/diagnostics")!

    /// A failure that repeats is one problem: one report a day for each.
    private static let errorInterval: TimeInterval = 86_400
    /// And never more than this many failure reports a day in all.
    private static let errorsPerDay = 20

    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "diagnostics")

    /// Thread-safe, so any code can write to it, on any thread.
    nonisolated static let breadcrumbs = BreadcrumbLog(url: URL.libraryDirectory.appending(path: "Logs/Cleen/breadcrumbs.log"))
    private let outbox = DiagnosticsOutbox(folder: URL.applicationSupportDirectory.appending(path: "app.cleen.Cleen/Diagnostics/Outbox", directoryHint: .isDirectory))
    private let reportsFolder = URL.libraryDirectory.appending(path: "Logs/DiagnosticReports", directoryHint: .isDirectory)
    private let scrubber = PersonalDataScrubber.current
    private lazy var identity = DiagnosticsIdentity(secret: Self.secret())
    private lazy var uploader = DiagnosticsUploader(endpoint: Self.endpoint, userAgent: Self.userAgent, transport: DiagnosticsUploader.session())

    private var started = false
    private var watcher: DispatchSourceFileSystemObject?
    private var subscriber: MetricKitSubscriber?
    private var pendingScan: Task<Void, Never>?
    private var flushing: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    private init() {
        UserDefaults.standard.register(defaults: [Self.sendsKey: true])
    }

    var sendsReports: Bool { UserDefaults.standard.bool(forKey: Self.sendsKey) }

    // MARK: Recording

    // Callable from any thread: capture and AVFoundation callbacks report failures too.

    /// A line in the log: what the app was doing, for a later report to show.
    nonisolated static func note(_ category: String, _ message: String) {
        breadcrumbs.record(.info, category, message)
    }

    /// Something worth noticing that isn't a failure (a permission missing).
    nonisolated static func warning(_ category: String, _ message: String) {
        breadcrumbs.record(.warning, category, message)
    }

    /// Something failed that shouldn't have: a line in the log and a report of its own.
    /// Only what can't identify anyone goes in `message`: an error's description, never
    /// a message's text or who it was for.
    nonisolated static func error(_ category: String, _ message: String) {
        breadcrumbs.record(.error, category, message)
        Task { @MainActor in shared.reportError(category, message) }
    }

    // MARK: Starting

    func start() {
        guard !started else { return }
        started = true
        let app = Self.appInfo
        let system = Self.systemInfo
        Self.note("launch", "Cleen \(app.version) (\(app.build)) on \(system.os), \(system.model)")
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Diagnostics.note("launch", "quit") }
        }

        let subscriber = MetricKitSubscriber { diagnostics in
            Task { @MainActor in Diagnostics.shared.received(diagnostics) }
        }
        MXMetricManager.shared.add(subscriber)
        self.subscriber = subscriber

        watchCrashReports()
        // Reading the reports folder is file IO: after launch has settled.
        scheduleScan(after: .seconds(8))
        Task {
            try? await Task.sleep(for: .seconds(20))
            flush()
        }
    }

    /// The switch in Ajustes moved.
    func sendingChanged(to on: Bool) {
        Self.note("diagnostics", on ? "sending turned on" : "sending turned off")
        if on {
            flush()
        } else {
            retry?.cancel()
            retry = nil
            outbox.clear()
        }
    }

    // MARK: Crash reports

    /// macOS writes each crash report into ~/Library/Logs/DiagnosticReports a moment after
    /// the crash: a helper's crash is read while Cleen still runs, Cleen's own at the next
    /// launch.
    private func watchCrashReports() {
        let fd = open(reportsFolder.path(percentEncoded: false), O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { Diagnostics.shared.scheduleScan(after: .seconds(3)) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    private func scheduleScan(after delay: Duration) {
        pendingScan?.cancel()
        pendingScan = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await Diagnostics.shared.scanCrashReports()
        }
    }

    private func scanCrashReports() async {
        let defaults = UserDefaults.standard
        let startedAt = Date.now
        // The first scan looks a week back, so crashes from before this version count too.
        let since = (defaults.object(forKey: Self.lastScanKey) as? Date) ?? startedAt.addingTimeInterval(-7 * 86_400)
        let seenList = defaults.stringArray(forKey: Self.seenKey) ?? []
        let seen = Set(seenList)
        let folder = reportsFolder
        let scan = await offMain { Self.readCrashReports(in: folder, since: since, excluding: seen) }
        // A minute of overlap: a report written during this scan is read by the next one.
        defaults.set(startedAt.addingTimeInterval(-60), forKey: Self.lastScanKey)
        defaults.set(Array((seenList + scan.read).suffix(400)), forKey: Self.seenKey)
        guard !scan.crashes.isEmpty else { return }
        for crash in scan.crashes {
            Self.note("crash", "\(crash.report.summary) at \(crash.occurredAt.formatted(.iso8601))")
            guard sendsReports else { continue }
            enqueue(crashReport(crash.report, occurredAt: crash.occurredAt))
        }
        flush()
    }

    /// Cleen's and its helpers' crash reports modified since `since`, oldest first, at
    /// most 20 a scan; `read` names every file looked at, so none is read twice.
    nonisolated private static func readCrashReports(in folder: URL, since: Date, excluding seen: Set<String>) -> (crashes: [(report: CrashReport, occurredAt: Date)], read: [String]) {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        var crashes: [(report: CrashReport, occurredAt: Date)] = []
        var read: [String] = []
        for directory in [folder, folder.appending(path: "Retired", directoryHint: .isDirectory)] {
            let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
            for url in urls where url.pathExtension == "ips" && !seen.contains(url.lastPathComponent) {
                guard let values = try? url.resourceValues(forKeys: keys),
                      let modified = values.contentModificationDate, modified >= since,
                      (values.fileSize ?? 0) < 8_000_000
                else { continue }
                read.append(url.lastPathComponent)
                guard let data = try? Data(contentsOf: url), let report = CrashReport(data: data),
                      report.belongs(toBundleID: "app.cleen.Cleen", name: "Cleen")
                else { continue }
                crashes.append((report, report.capturedAt ?? modified))
            }
        }
        return (Array(crashes.sorted { $0.occurredAt < $1.occurredAt }.suffix(20)), read)
    }

    private func crashReport(_ crash: CrashReport, occurredAt: Date) -> DiagnosticReport {
        // Cleen's own report says which version crashed; a helper's speaks for the helper
        // (perl's), so the running Cleen's stands in.
        let ownProcess = crash.process == "Cleen"
        let app = DiagnosticReport.App(
            version: (ownProcess ? crash.appVersion : nil) ?? Self.appInfo.version,
            build: (ownProcess ? crash.appBuild : nil) ?? Self.appInfo.build
        )
        let system = DiagnosticReport.System(os: crash.osVersion ?? Self.systemInfo.os, model: crash.model ?? Self.systemInfo.model)
        return report(kind: .crash, signature: crash.signature, summary: crash.summary, process: crash.process,
                      occurredAt: occurredAt, app: app, system: system, body: String(decoding: crash.sanitizedBody, as: UTF8.self))
    }

    // MARK: MetricKit

    private func received(_ diagnostics: [MetricDiagnostic]) {
        for diagnostic in diagnostics {
            let frames = MetricKitStack.frames(inCallStackTree: diagnostic.callStack)
            let signature = MetricKitStack.signature(kind: diagnostic.kind, process: "Cleen", frames: frames)
            Self.note("metrickit", diagnostic.detail)
            guard sendsReports else { continue }
            let summary = ["Cleen", diagnostic.detail, frames.first].compactMap { $0 }.joined(separator: " · ")
            enqueue(report(kind: diagnostic.kind, signature: signature, summary: summary, process: "Cleen", occurredAt: diagnostic.occurredAt,
                           app: .init(version: Self.appInfo.version, build: diagnostic.build ?? Self.appInfo.build), system: Self.systemInfo,
                           body: String(decoding: diagnostic.json, as: UTF8.self)))
        }
        flush()
    }

    // MARK: Failures

    private func reportError(_ category: String, _ message: String) {
        guard sendsReports else { return }
        let signature = DiagnosticReport.signature(["error", category, message])
        let now = Date.now
        let defaults = UserDefaults.standard
        var sent = (defaults.dictionary(forKey: Self.errorsSentKey) as? [String: Date] ?? [:])
            .filter { now.timeIntervalSince($0.value) < Self.errorInterval }
        guard sent[signature] == nil, sent.count < Self.errorsPerDay else { return }
        sent[signature] = now
        defaults.set(sent, forKey: Self.errorsSentKey)
        let body = (try? JSONSerialization.data(withJSONObject: ["category": category, "message": message], options: [.sortedKeys, .withoutEscapingSlashes]))
            .map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        enqueue(report(kind: .error, signature: signature, summary: "Cleen · \(category) · \(message)", process: "Cleen", occurredAt: now,
                       app: Self.appInfo, system: Self.systemInfo, body: body))
        flush()
    }

    // MARK: Queue and send

    private func report(kind: DiagnosticReport.Kind, signature: String, summary: String, process: String, occurredAt: Date,
                        app: DiagnosticReport.App, system: DiagnosticReport.System, body: String) -> DiagnosticReport {
        // The server takes a summary of up to 400 characters.
        DiagnosticReport(kind: kind, signature: signature, summary: String(summary.prefix(300)), process: process, occurredAt: occurredAt,
                         app: app, system: system, install: identity.install(for: signature),
                         breadcrumbs: Self.breadcrumbs.lines(before: occurredAt, limit: 80), report: body)
            .scrubbed(by: scrubber)
    }

    private func enqueue(_ report: DiagnosticReport) {
        do {
            try outbox.add(report)
        } catch {
            Self.log.error("couldn't queue a report: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Sends what's queued, one flush at a time; what the server couldn't take now is
    /// tried again in half an hour.
    private func flush() {
        guard sendsReports, flushing == nil else { return }
        let uploader = uploader
        let outbox = outbox
        flushing = Task {
            let result = await uploader.flush(outbox)
            Diagnostics.shared.flushed(delivered: result.delivered, kept: result.kept)
        }
    }

    private func flushed(delivered: Int, kept: Int) {
        flushing = nil
        if delivered > 0 { Self.log.info("sent \(delivered) report(s)") }
        guard kept > 0, retry == nil else { return }
        retry = Task {
            try? await Task.sleep(for: .seconds(30 * 60))
            Diagnostics.shared.retry = nil
            Diagnostics.shared.flush()
        }
    }

    // MARK: This Mac

    static let appInfo = DiagnosticReport.App(
        version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    )

    static let systemInfo: DiagnosticReport.System = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let build = sysctl("kern.osversion").map { " (\($0))" } ?? ""
        return .init(os: "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)\(build)", model: sysctl("hw.model") ?? "Mac")
    }()

    private static var userAgent: String { "Cleen/\(appInfo.version) (\(appInfo.build)); \(systemInfo.os)" }

    private static var endpoint: URL {
        UserDefaults.standard.string(forKey: endpointKey).flatMap(URL.init(string:)) ?? defaultEndpoint
    }

    /// Made once per install, kept only here: see `DiagnosticsIdentity`.
    private static func secret() -> String {
        let defaults = UserDefaults.standard
        if let secret = defaults.string(forKey: secretKey) { return secret }
        let secret = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        defaults.set(secret, forKey: secretKey)
        return secret
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}

/// One MetricKit diagnostic as plain values: they arrive on a queue of MetricKit's.
struct MetricDiagnostic: Sendable {
    let kind: DiagnosticReport.Kind
    /// "hang 2.4 s", "cpu 92 s in 180 s", "disk writes 2,100 MB".
    let detail: String
    let callStack: Data
    let json: Data
    let build: String?
    let occurredAt: Date
}

/// Receives MetricKit's diagnostic payloads (delivered at most daily, often at launch).
/// Crashes are left to the system's crash reports, which carry every thread.
nonisolated final class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    private let receive: @Sendable ([MetricDiagnostic]) -> Void

    init(receive: @escaping @Sendable ([MetricDiagnostic]) -> Void) {
        self.receive = receive
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var diagnostics: [MetricDiagnostic] = []
        for payload in payloads {
            let end = payload.timeStampEnd
            for hang in payload.hangDiagnostics ?? [] {
                let seconds = hang.hangDuration.converted(to: .seconds).value
                diagnostics.append(MetricDiagnostic(kind: .hang, detail: "hang \(seconds.formatted(.number.precision(.fractionLength(1)))) s",
                                                    callStack: hang.callStackTree.jsonRepresentation(), json: hang.jsonRepresentation(),
                                                    build: hang.metaData.applicationBuildVersion, occurredAt: end))
            }
            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                let used = cpu.totalCPUTime.converted(to: .seconds).value
                let over = cpu.totalSampledTime.converted(to: .seconds).value
                diagnostics.append(MetricDiagnostic(kind: .cpuException, detail: "cpu \(Int(used)) s in \(Int(over)) s",
                                                    callStack: cpu.callStackTree.jsonRepresentation(), json: cpu.jsonRepresentation(),
                                                    build: cpu.metaData.applicationBuildVersion, occurredAt: end))
            }
            for disk in payload.diskWriteExceptionDiagnostics ?? [] {
                let megabytes = disk.totalWritesCaused.converted(to: .megabytes).value
                diagnostics.append(MetricDiagnostic(kind: .diskWrites, detail: "disk writes \(Int(megabytes)) MB",
                                                    callStack: disk.callStackTree.jsonRepresentation(), json: disk.jsonRepresentation(),
                                                    build: disk.metaData.applicationBuildVersion, occurredAt: end))
            }
        }
        if !diagnostics.isEmpty { receive(diagnostics) }
    }
}
