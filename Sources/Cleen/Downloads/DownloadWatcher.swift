import AppKit
import CleenKit
import Observation
import os

/// Downloads in progress, as Finder sees them: browsers (Chrome, Dia, Safari, Firefox)
/// publish each download's progress for its file, the same progress Finder draws on the
/// file's icon, and Cleen subscribes to the Downloads folder's. That gives the real size
/// and bytes so far; the speed and the time left are measured from them.
@Observable
final class DownloadWatcher {
    struct Download: Identifiable, Equatable {
        let id: ObjectIdentifier
        /// The name it'll have once done (without `.crdownload` and the like).
        var name: String
        var url: URL?
        var estimate: DownloadEstimate
    }

    /// Running, the one furthest from done first (what the notch shows).
    private(set) var active: [Download] = []
    /// Called once a download completes, with its finished file and the size the
    /// browser announced.
    @ObservationIgnored var onFinished: (URL, Int64) -> Void = { _, _ in }

    @ObservationIgnored private var subscriber: Any?
    @ObservationIgnored private var tracked: [ObjectIdentifier: Progress] = [:]
    @ObservationIgnored private var poll: Task<Void, Never>?
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "downloads")

    static var folder: URL { URL.downloadsDirectory }

    func start() {
        guard subscriber == nil else { return }
        subscriber = Progress.addSubscriber(forFileURL: Self.folder) { [weak self] progress in
            let box = ProgressBox(progress)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.published(box.progress) }
            }
            return {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.unpublished(box.progress) }
                }
            }
        }
    }

    func stop() {
        if let subscriber { Progress.removeSubscriber(subscriber) }
        subscriber = nil
        poll?.cancel()
        poll = nil
        tracked.removeAll()
        active.removeAll()
    }

    private func published(_ progress: Progress) {
        // Only downloads: copies and other file operations publish here too.
        if let kind = progress.fileOperationKind, kind != .downloading { return }
        let id = ObjectIdentifier(progress)
        tracked[id] = progress
        Self.log.notice("download started: \(progress.totalUnitCount, privacy: .public) bytes")
        sample()
        startPolling()
    }

    private func unpublished(_ progress: Progress) {
        let id = ObjectIdentifier(progress)
        guard tracked.removeValue(forKey: id) != nil else { return }
        let entry = active.first { $0.id == id }
        active.removeAll { $0.id == id }
        if tracked.isEmpty {
            poll?.cancel()
            poll = nil
        }
        // Finished, not cancelled: everything arrived, or the file has its final name.
        let done = progress.isFinished || (progress.totalUnitCount > 0 && progress.completedUnitCount >= progress.totalUnitCount)
        guard !progress.isCancelled, let entry else { return }
        let final = Self.finalURL(entry)
        if done || final.map({ FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }) == true, let final {
            onFinished(final, max(entry.estimate.total, progress.totalUnitCount))
        }
    }

    private func startPolling() {
        guard poll == nil else { return }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                self?.sample()
            }
        }
    }

    /// Reads every tracked progress and updates the estimates.
    private func sample() {
        let now = Date.now
        var next: [Download] = []
        for (id, progress) in tracked {
            var entry = active.first { $0.id == id } ?? Download(id: id, name: Self.name(of: progress), url: Self.url(of: progress), estimate: DownloadEstimate())
            entry.estimate.update(completed: progress.completedUnitCount, total: progress.totalUnitCount, at: now)
            entry.name = Self.name(of: progress)
            next.append(entry)
        }
        next.sort { ($0.estimate.remaining ?? .infinity) > ($1.estimate.remaining ?? .infinity) }
        if next != active { active = next }
    }

    private static func url(of progress: Progress) -> URL? {
        progress.fileURL ?? (progress.userInfo[.fileURLKey] as? URL)
    }

    private static func name(of progress: Progress) -> String {
        DownloadEstimate.finalName(of: url(of: progress)?.lastPathComponent ?? String(localized: "Download"))
    }

    /// Where the finished file is: the published URL without the browser's suffix.
    private static func finalURL(_ entry: Download) -> URL? {
        guard let url = entry.url else { return nil }
        return url.deletingLastPathComponent().appending(path: DownloadEstimate.finalName(of: url.lastPathComponent))
    }
}

/// Hands a progress from the subscription's queue to the main thread; it's only read there.
private nonisolated struct ProgressBox: @unchecked Sendable {
    let progress: Progress
    init(_ progress: Progress) { self.progress = progress }
}
