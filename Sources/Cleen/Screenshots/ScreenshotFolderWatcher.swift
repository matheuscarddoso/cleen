import Darwin
import Foundation

/// Watches the folders macOS saves screenshots to and reports the captures in them.
///
/// A capture is recognized by the `com.apple.metadata:kMDItemIsScreenCapture` attribute
/// the screenshot service writes on the file itself, so it works the instant the file
/// lands — Spotlight can take minutes to index it, or stall on a full disk.
nonisolated final class ScreenshotFolderWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.cleen.screenshots")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
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
                let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: queue)
                source.setEventHandler { [weak self] in self?.scheduleScan() }
                source.setCancelHandler { close(fd) }
                source.resume()
                sources.append(source)
            }
        }
    }

    /// The service writes the file first and tags it as a screenshot a little later, and
    /// tagging doesn't touch the folder again, so look a few times over the next seconds.
    private func scheduleScan() {
        pending?.cancel()
        let work = DispatchWorkItem { [onChange, queue] in
            onChange()
            for delay in [0.8, 2.0, 4.5] {
                queue.asyncAfter(deadline: .now() + delay) { onChange() }
            }
        }
        pending = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Screenshots in the watched folders taken after `since`, newest first.
    static func captures(since: Date) -> [(url: URL, date: Date)] {
        let keys: Set<URLResourceKey> = [.creationDateKey]
        return folders.flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        }
        .compactMap { url -> (URL, Date)? in
            guard ["png", "jpg", "jpeg", "heic", "tiff", "pdf"].contains(url.pathExtension.lowercased()),
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
}
