import CleenKit
import Darwin
import Foundation

/// Watches the folders macOS saves screenshots to and reports the captures in them.
///
/// A capture is recognized by the `com.apple.metadata:kMDItemIsScreenCapture` attribute
/// the screenshot service writes on the file itself, so it works the instant the file
/// lands — Spotlight can take minutes to index it, or stall on a full disk.
///
/// New captures are found without rescanning the folder: on each change only the names
/// that weren't there a moment ago are looked at, so a capture is reported within a few
/// milliseconds of landing even on a Desktop with thousands of files. A full listing
/// still follows a second later, to keep the list right when files go away.
nonisolated final class ScreenshotFolderWatcher: @unchecked Sendable {
    /// A capture as it lands.
    struct Capture: Sendable {
        let url: URL
        let date: Date
        /// The area it covers, in global display coordinates (see `ScreenCapturePicker`).
        let rect: CGRect?
    }

    private static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "pdf"]
    /// How long a new file is watched for the screenshot tag, and how often.
    private static let tagWait = 4.0
    private static let tagPoll = 0.05

    private let queue = DispatchQueue(label: "app.cleen.screenshots", qos: .userInitiated)
    private var sources: [DispatchSourceFileSystemObject] = []
    /// Each folder's names as last seen. Confined to `queue`.
    private var names: [URL: Set<String>] = [:]
    /// New image files not tagged yet, with when to give up on them. Confined to `queue`.
    private var untagged: [URL: Date] = [:]
    private var polling = false
    private var pendingSync: DispatchWorkItem?
    private let onCaptures: @Sendable ([Capture]) -> Void
    private let onChange: @Sendable () -> Void

    /// `onCaptures` gets new captures the moment they're tagged; `onChange`, a settled
    /// moment after the folders changed, for a full listing.
    init(onCaptures: @escaping @Sendable ([Capture]) -> Void, onChange: @escaping @Sendable () -> Void) {
        self.onCaptures = onCaptures
        self.onChange = onChange
    }

    /// The save location from the Screenshot app's options, plus the Desktop.
    static var folders: [URL] {
        let desktop = URL.homeDirectory.appending(path: "Desktop", directoryHint: .isDirectory)
        let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
            .map { URL(filePath: ($0 as NSString).expandingTildeInPath, directoryHint: .isDirectory) }
        var seen = Set<String>()
        return [configured, desktop].compactMap { $0 }.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    func start() {
        queue.async { [self] in
            for folder in Self.folders {
                let fd = open(folder.path(percentEncoded: false), O_EVTONLY)
                guard fd >= 0 else { continue }
                names[folder] = Self.list(folder)
                let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: queue)
                source.setEventHandler { [weak self] in self?.folderChanged(folder) }
                source.setCancelHandler { close(fd) }
                source.resume()
                sources.append(source)
            }
        }
    }

    // MARK: On the queue

    /// Names only: no attributes, so it costs next to nothing however full the folder is.
    private static func list(_ folder: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? [])
    }

    private func folderChanged(_ folder: URL) {
        let now = Self.list(folder)
        let added = now.subtracting(names[folder] ?? [])
        names[folder] = now
        // The service writes a hidden temporary file and renames it: only the final,
        // visible name is the capture.
        for name in added where !name.hasPrefix(".") && Self.extensions.contains((name as NSString).pathExtension.lowercased()) {
            untagged[folder.appending(path: name)] = .now.addingTimeInterval(Self.tagWait)
        }
        checkUntagged()
        scheduleSync()
    }

    /// Reports the new files that carry the tag now; the rest are looked at again shortly,
    /// until they're tagged or it's clear they're not captures.
    private func checkUntagged() {
        var found: [Capture] = []
        for (url, deadline) in untagged {
            if Self.isScreenCapture(url) {
                untagged[url] = nil
                found.append(Capture(url: url, date: Self.creationDate(url) ?? .now, rect: Self.captureRect(url)))
            } else if deadline < .now || !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                untagged[url] = nil
            }
        }
        if !found.isEmpty { onCaptures(found.sorted { $0.date > $1.date }) }
        guard !untagged.isEmpty, !polling else { return }
        polling = true
        queue.asyncAfter(deadline: .now() + Self.tagPoll) { [weak self] in
            guard let self else { return }
            polling = false
            checkUntagged()
        }
    }

    /// One full listing once the folder settles (several events arrive per capture).
    private func scheduleSync() {
        pendingSync?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        pendingSync = work
        queue.asyncAfter(deadline: .now() + 1, execute: work)
    }

    // MARK: Reading files

    /// Screenshots in the watched folders taken after `since`, newest first.
    static func captures(since: Date) -> [(url: URL, date: Date)] {
        let keys: Set<URLResourceKey> = [.creationDateKey]
        return folders.flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        }
        .compactMap { url -> (URL, Date)? in
            guard extensions.contains(url.pathExtension.lowercased()),
                  let date = try? url.resourceValues(forKeys: keys).creationDate, date >= since,
                  isScreenCapture(url)
            else { return nil }
            return (url, date)
        }
        .sorted { $0.1 > $1.1 }
        .map { (url: $0.0, date: $0.1) }
    }

    static func isScreenCapture(_ url: URL) -> Bool {
        getxattr(url.path(percentEncoded: false), "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    private static func creationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    private static func captureRect(_ url: URL) -> CGRect? {
        let path = url.path(percentEncoded: false)
        let name = "com.apple.metadata:kMDItemScreenCaptureGlobalRect"
        let size = getxattr(path, name, nil, 0, 0, 0)
        guard size > 0, size < 4096 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
        guard read == size else { return nil }
        return ScreenCapturePicker.globalRect(fromAttribute: data)
    }
}
