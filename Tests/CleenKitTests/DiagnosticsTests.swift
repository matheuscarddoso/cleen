import Foundation
import Testing
@testable import CleenKit

/// A crash report shaped like the ones macOS wrote for the Now Playing helper on
/// 2026-11-16: perl, run by Cleen, aborting inside NSJSONSerialization.
private func helperCrash(home: String = "/Users/someone", topSymbol: String = "Write", bugType: String = "309") -> Data {
    let header = #"{"app_name":"perl","timestamp":"2026-11-16 10:48:37.00 -0300","app_version":"","bug_type":"\#(bugType)","os_version":"macOS 26.5.1 (25F80)","name":"perl"}"#
    let body: [String: Any] = [
        "procName": "perl", "procPath": "/usr/bin/perl", "parentProc": "Cleen", "responsibleProc": "Cleen",
        "coalitionName": "app.cleen.Cleen", "modelCode": "Mac15,12", "captureTime": "2026-11-16 10:48:34.8721 -0300",
        "crashReporterKey": "00000000-1111-2222-3333-444444444444", "sleepWakeUUID": "55555555", "bootSessionUUID": "66666666",
        "exception": ["type": "EXC_CRASH", "signal": "SIGABRT"],
        "termination": ["indicator": "Abort trap: 6"],
        "asi": ["libsystem_c.dylib": ["abort() called"]],
        "faultingThread": 0,
        "usedImages": [
            ["name": "libsystem_kernel.dylib", "path": "/usr/lib/system/libsystem_kernel.dylib"],
            ["name": "libsystem_c.dylib", "path": "/usr/lib/system/libsystem_c.dylib"],
            ["name": "Foundation", "path": "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation"],
            ["path": "\(home)/Applications/Cleen.app/Contents/Resources/libCleenNowPlaying.dylib"],
        ],
        "threads": [[
            "triggered": true,
            "frames": [
                ["imageIndex": 0, "symbol": "__pthread_kill", "imageOffset": 38376],
                ["imageIndex": 1, "symbol": "abort", "imageOffset": 492100],
                ["imageIndex": 2, "symbol": "_writeJSONNumber", "imageOffset": 659148],
                ["imageIndex": 3, "symbol": topSymbol, "imageOffset": 5484],
            ],
        ]],
    ]
    var data = Data(header.utf8)
    data.append(UInt8(ascii: "\n"))
    data.append(try! JSONSerialization.data(withJSONObject: body))
    return data
}

@Suite struct CrashReportTests {
    @Test func readsWhatTheSystemWrote() throws {
        let report = try #require(CrashReport(data: helperCrash()))
        #expect(report.process == "perl")
        #expect(report.exceptionType == "EXC_CRASH")
        #expect(report.signal == "SIGABRT")
        #expect(report.termination == "Abort trap: 6")
        #expect(report.reason == "abort() called")
        #expect(report.osVersion == "macOS 26.5.1 (25F80)")
        #expect(report.appVersion == nil)
        // 10:48:34 at -03:00 is 13:48:34 UTC; the fraction is dropped.
        #expect(report.capturedAt == Date(timeIntervalSince1970: 1_794_836_914))
        #expect(report.frames.map(\.image) == ["libsystem_kernel.dylib", "libsystem_c.dylib", "Foundation", "libCleenNowPlaying.dylib"])
    }

    @Test func belongsToCleenThroughItsHelpers() throws {
        let report = try #require(CrashReport(data: helperCrash()))
        #expect(report.belongs(toBundleID: "app.cleen.Cleen", name: "Cleen"))
        #expect(!report.belongs(toBundleID: "com.example.Other", name: "Other"))
    }

    @Test func theSignatureLooksPastTheAbortPlumbing() throws {
        let report = try #require(CrashReport(data: helperCrash()))
        #expect(report.tellingFrames.map(\.image) == ["Foundation", "libCleenNowPlaying.dylib"])
        // The summary points at Cleen's own code, where the fix goes.
        #expect(report.summary == "perl · EXC_CRASH (SIGABRT) · libCleenNowPlaying.dylib Write")
    }

    @Test func theSameCrashHasTheSameSignatureOnEveryMac() throws {
        let one = try #require(CrashReport(data: helperCrash(home: "/Users/ana")))
        let other = try #require(CrashReport(data: helperCrash(home: "/Users/bruno")))
        let different = try #require(CrashReport(data: helperCrash(topSymbol: "Emit")))
        #expect(one.signature == other.signature)
        #expect(one.signature != different.signature)
        #expect(one.signature.count == 16)
    }

    @Test func dropsWhatIdentifiesTheMac() throws {
        let report = try #require(CrashReport(data: helperCrash()))
        let body = try #require(try JSONSerialization.jsonObject(with: report.sanitizedBody) as? [String: Any])
        #expect(body["crashReporterKey"] == nil)
        #expect(body["sleepWakeUUID"] == nil)
        #expect(body["bootSessionUUID"] == nil)
        // What symbolicating needs stays.
        #expect(body["threads"] != nil)
        #expect(body["usedImages"] != nil)
    }

    @Test func onlyCrashesAreRead() {
        #expect(CrashReport(data: helperCrash(bugType: "288")) == nil)
        #expect(CrashReport(data: Data("not a report".utf8)) == nil)
        #expect(CrashReport(data: Data()) == nil)
    }
}

@Suite struct PersonalDataScrubberTests {
    private let scrubber = PersonalDataScrubber(home: "/Users/ana", names: ["ana", "Ana Souza", "MacBook da Ana", "Al"])

    @Test func takesTheHomeFolderOutOfPaths() {
        #expect(scrubber.scrub("/Users/ana/Desktop/Screenshot.png") == "~/Desktop/Screenshot.png")
        #expect(scrubber.scrub("/Users/visita/Downloads/a.dmg") == "/Users/<user>/Downloads/a.dmg")
        #expect(scrubber.scrub("/Users/Shared/cache") == "/Users/Shared/cache")
    }

    @Test func takesNamesAndAddressesOut() {
        #expect(scrubber.scrub("MacBook da Ana asleep") == "<redacted> asleep")
        #expect(scrubber.scrub("signed by Ana Souza") == "signed by <redacted>")
        #expect(scrubber.scrub("mail me at someone@example.com") == "mail me at <email>")
    }

    @Test func leavesShortNamesAlone() {
        #expect(scrubber.scrub("Alloc failed") == "Alloc failed")
    }

    @Test func aWholeCrashReportComesOutClean() throws {
        let report = try #require(CrashReport(data: helperCrash(home: "/Users/ana")))
        let text = scrubber.scrub(String(decoding: report.sanitizedBody, as: UTF8.self))
        #expect(!text.contains("/Users/ana"))
        #expect(text.contains("~/Applications/Cleen.app"))
    }
}

@Suite struct DiagnosticsIdentityTests {
    @Test func oneInstallLooksDifferentForEveryProblem() {
        let identity = DiagnosticsIdentity(secret: "s3cret")
        #expect(identity.install(for: "aaaa") == identity.install(for: "aaaa"))
        #expect(identity.install(for: "aaaa") != identity.install(for: "bbbb"))
        #expect(DiagnosticsIdentity(secret: "other").install(for: "aaaa") != identity.install(for: "aaaa"))
    }
}

@Suite struct MetricKitStackTests {
    @Test func followsTheAttributedThreadInnermostFirst() throws {
        let tree: [String: Any] = ["callStacks": [
            ["threadAttributed": false, "callStackRootFrames": [["binaryName": "Other", "offsetIntoBinaryTextSegment": 1]]],
            ["threadAttributed": true, "callStackRootFrames": [[
                "binaryName": "Cleen", "offsetIntoBinaryTextSegment": 100,
                "subFrames": [["binaryName": "SwiftUI", "offsetIntoBinaryTextSegment": 200,
                               "subFrames": [["binaryName": "AppKit", "offsetIntoBinaryTextSegment": 300]]]],
            ]]],
        ]]
        let json = try JSONSerialization.data(withJSONObject: tree)
        #expect(MetricKitStack.frames(inCallStackTree: json) == ["Cleen+100", "SwiftUI+200", "AppKit+300"])
        #expect(MetricKitStack.frames(inCallStackTree: json, limit: 2) == ["Cleen+100", "SwiftUI+200"])
        #expect(MetricKitStack.frames(inCallStackTree: Data("{}".utf8)).isEmpty)
    }
}

@Suite struct BreadcrumbLogTests {
    @Test func keepsLinesAcrossLaunchesOldestFirst() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("Logs/breadcrumbs.log")
        BreadcrumbLog(url: url).record(.info, "launch", "1.2.4 (174)")
        let next = BreadcrumbLog(url: url)
        next.record(.error, "now-playing", "helper exited\nrestarting")
        let lines = next.lines()
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix("I [launch] 1.2.4 (174)"))
        #expect(lines[1].hasSuffix("E [now-playing] helper exited restarting"))
    }

    @Test func onlyWhatCameBeforeTheCrash() throws {
        let sandbox = try Sandbox()
        let log = BreadcrumbLog(url: sandbox.url("breadcrumbs.log"))
        let crash = Date(timeIntervalSince1970: 1_800_000_000)
        log.record(.info, "a", "before", at: crash.addingTimeInterval(-60))
        log.record(.info, "a", "after", at: crash.addingTimeInterval(60))
        #expect(log.lines(before: crash).map { $0.hasSuffix("before") } == [true])
        #expect(log.lines(limit: 1).first?.hasSuffix("after") == true)
    }

    @Test func turnsOverWithoutLosingTheRecentPast() throws {
        let sandbox = try Sandbox()
        let log = BreadcrumbLog(url: sandbox.url("breadcrumbs.log"), maxBytes: 200)
        for index in 0..<20 { log.record(.info, "loop", "line \(index)") }
        let lines = log.lines()
        #expect(lines.last?.hasSuffix("line 19") == true)
        #expect(lines.count < 20)
        #expect(sandbox.exists("breadcrumbs.log.1"))
    }
}

@Suite struct DiagnosticsOutboxTests {
    private func report(at date: Date, signature: String = "abc") -> DiagnosticReport {
        DiagnosticReport(kind: .crash, signature: signature, summary: "perl · EXC_CRASH", process: "perl", occurredAt: date,
                         app: .init(version: "1.2.4", build: "174"), system: .init(os: "macOS 26.5.1", model: "Mac15,12"),
                         install: "i", breadcrumbs: [], report: "{}")
    }

    @Test func keepsReportsUntilSentOldestFirst() throws {
        let sandbox = try Sandbox()
        let outbox = DiagnosticsOutbox(folder: sandbox.url("outbox"))
        let now = Date.now
        try outbox.add(report(at: now, signature: "new"))
        try outbox.add(report(at: now.addingTimeInterval(-60), signature: "old"))
        #expect(outbox.pending().map(\.report.signature) == ["old", "new"])
    }

    @Test func dropsTheOldestBeyondTheLimitAndTheExpired() throws {
        let sandbox = try Sandbox()
        let outbox = DiagnosticsOutbox(folder: sandbox.url("outbox"), maxCount: 2, maxAge: 3_600)
        let now = Date.now
        try outbox.add(report(at: now.addingTimeInterval(-7_200), signature: "expired"))
        try outbox.add(report(at: now.addingTimeInterval(-60), signature: "a"))
        try outbox.add(report(at: now, signature: "b"))
        #expect(outbox.pending(now: now).map(\.report.signature) == ["a", "b"])
        outbox.clear()
        #expect(outbox.pending().isEmpty)
    }
}

@Suite struct DiagnosticsUploaderTests {
    private func report(_ signature: String) -> DiagnosticReport {
        DiagnosticReport(kind: .hang, signature: signature, summary: "s", process: "Cleen", occurredAt: .now,
                         app: .init(version: "1", build: "1"), system: .init(os: "macOS", model: "Mac"), install: "i", breadcrumbs: [], report: "{}")
    }

    @Test func tellsWhatToKeep() {
        #expect(DiagnosticsUploader.outcome(status: 202) == .delivered)
        #expect(DiagnosticsUploader.outcome(status: 400) == .rejected)
        #expect(DiagnosticsUploader.outcome(status: 413) == .rejected)
        #expect(DiagnosticsUploader.outcome(status: 404) == .retryLater)
        #expect(DiagnosticsUploader.outcome(status: 429) == .retryLater)
        #expect(DiagnosticsUploader.outcome(status: 503) == .retryLater)
    }

    @Test func sendsTheReportAsJSON() async throws {
        let seen = Recorder()
        let uploader = DiagnosticsUploader(endpoint: URL(string: "https://example.com/api/diagnostics")!, userAgent: "Cleen/1.2.4 (174)") { request in
            await seen.keep(request)
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!)
        }
        #expect(await uploader.send(report("abc")) == .delivered)
        let request = try #require(await seen.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Cleen/1.2.4 (174)")
        let sent = try DiagnosticReport.decoder.decode(DiagnosticReport.self, from: try #require(request.httpBody))
        #expect(sent.signature == "abc")
        #expect(sent.schema == DiagnosticReport.schemaVersion)
    }

    @Test func aServerThatsDownKeepsTheRestQueued() async throws {
        let sandbox = try Sandbox()
        let outbox = DiagnosticsOutbox(folder: sandbox.url("outbox"))
        try outbox.add(report("one"))
        try outbox.add(report("two"))
        let calls = Recorder()
        let uploader = DiagnosticsUploader(endpoint: URL(string: "https://example.com")!, userAgent: "t") { request in
            await calls.keep(request)
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
        }
        let result = await uploader.flush(outbox)
        #expect(result.delivered == 0 && result.kept == 2)
        #expect(await calls.requests.count == 1)
        #expect(outbox.pending().count == 2)
    }

    @Test func offlineIsRetriedLater() async throws {
        let uploader = DiagnosticsUploader(endpoint: URL(string: "https://example.com")!, userAgent: "t") { _ in throw URLError(.notConnectedToInternet) }
        #expect(await uploader.send(report("x")) == .retryLater)
    }
}

private actor Recorder {
    var requests: [URLRequest] = []
    func keep(_ request: URLRequest) { requests.append(request) }
}
