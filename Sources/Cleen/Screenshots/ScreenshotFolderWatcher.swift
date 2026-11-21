import CleenKit
import Darwin
import Foundation

/// Watches the folders macOS saves screenshots and screen recordings to and reports the
/// captures in them.
///
/// A capture is recognized by the `com.apple.metadata:kMDItemIsScreenCapture` attribute
/// the screenshot service writes on the file, without waiting for Spotlight to index it
/// (that can take minutes, or stall on a full disk). The attribute is written through
/// Spotlight's metadata service, though, and never arrives while the volume's index is
/// broken; a new file it hasn't reached shortly after landing is recognized by the mark
/// the service writes inside the file itself (`ScreenCaptureMarker`). A recording lands
/// in one piece once it's stopped, so its mark can be read as soon as its name appears.
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

    /// Screenshots in any format the Screenshot app saves, and its recordings.
    private static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "pdf", "mov", "mp4"]
    /// How long a new file is watched for the screenshot tag, and how often.
    private static let tagWait = 4.0
    private static let tagPoll = 0.05
    /// How long the tag gets before the image's own marker is read instead. The tag
    /// arrives about 0.1 s after the file and carries the area each file covers, which
    /// picks the right display's file of a ⌘⇧3; the marker doesn't.
    private static let tagGrace = 0.3

    /// A new image or movie not recognized yet. Confined to `queue`.
    private struct Pending {
        /// When to stop waiting for the tag and read the marker.
        let markerAt: Date
        /// When to give up on it.
        let deadline: Date
        /// A movie's marker is being read (AVFoundation answers asynchronously); it isn't
        /// given up on until the answer is in.
        var markerReading = false
        /// The marker was read and isn't there: only the tag can still make it a capture.
        var markerAbsent = false
    }

    private let queue = DispatchQueue(label: "app.cleen.screenshots", qos: .userInitiated)
    private var sources: [DispatchSourceFileSystemObject] = []
    /// Each folder's names as last seen. Confined to `queue`.
    private var names: [URL: Set<String>] = [:]
    /// New files not recognized yet. Confined to `queue`.
    private var untagged: [URL: Pending] = [:]
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
        let landed = Date.now
        for name in added where !name.hasPrefix(".") && Self.extensions.contains((name as NSString).pathExtension.lowercased()) {
            untagged[folder.appending(path: name)] = Pending(markerAt: landed.addingTimeInterval(Self.tagGrace), deadline: landed.addingTimeInterval(Self.tagWait))
        }
        checkUntagged()
        scheduleSync()
    }

    /// Reports the new files that are captures now: tagged, or past the grace and carrying
    /// the marker. The rest are looked at again shortly, until they're recognized or it's
    /// clear they're not captures.
    private func checkUntagged() {
        var found: [Capture] = []
        let now = Date.now
        for (url, pending) in untagged {
            if Self.isTaggedScreenCapture(url) {
                untagged[url] = nil
                found.append(Capture(url: url, date: Self.creationDate(url) ?? now, rect: Self.captureRect(url)))
            } else if (pending.deadline < now && !pending.markerReading) || !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                untagged[url] = nil
            } else if now >= pending.markerAt, !pending.markerAbsent, !pending.markerReading {
                if ScreenCaptureMarker.isMovie(url) {
                    untagged[url]?.markerReading = true
                    Task { [weak self] in
                        let present = await ScreenCaptureMarker.isPresent(inMovieAt: url)
                        self?.queue.async { self?.markerRead(url, present: present) }
                    }
                } else if ScreenCaptureMarker.isPresent(inImageAt: url) {
                    untagged[url] = nil
                    found.append(Capture(url: url, date: Self.creationDate(url) ?? now, rect: nil))
                } else {
                    untagged[url]?.markerAbsent = true
                }
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

    /// A movie's marker, read: a recording is reported, anything else waits out the tag.
    /// The tag may have come (or the file gone) while it was being read.
    private func markerRead(_ url: URL, present: Bool) {
        guard untagged[url] != nil else { return }
        if present {
            untagged[url] = nil
            onCaptures([Capture(url: url, date: Self.creationDate(url) ?? .now, rect: nil)])
        } else {
            untagged[url]?.markerReading = false
            untagged[url]?.markerAbsent = true
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

    /// Screenshots and recordings in the watched folders taken after `since`, newest
    /// first. Blocking file IO (the Desktop can hold thousands of files), so it runs off
    /// the main thread.
    @concurrent static func captures(since: Date) async -> [(url: URL, date: Date)] {
        let keys: Set<URLResourceKey> = [.creationDateKey]
        var found: [(url: URL, date: Date)] = []
        var movies: [(url: URL, date: Date)] = []
        for folder in folders {
            let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
            for url in urls {
                guard extensions.contains(url.pathExtension.lowercased()),
                      let date = try? url.resourceValues(forKeys: keys).creationDate, date >= since
                else { continue }
                if isTaggedScreenCapture(url) {
                    found.append((url, date))
                } else if ScreenCaptureMarker.isMovie(url) {
                    movies.append((url, date))
                } else if ScreenCaptureMarker.isPresent(inImageAt: url) {
                    found.append((url, date))
                }
            }
        }
        // Untagged movies last, their headers read only for the few left.
        for movie in movies where await ScreenCaptureMarker.isPresent(inMovieAt: movie.url) {
            found.append(movie)
        }
        return found.sorted { $0.date > $1.date }
    }

    /// The tag alone: one xattr read, so it goes first and the marker is read only when
    /// it's missing.
    private static func isTaggedScreenCapture(_ url: URL) -> Bool {
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
