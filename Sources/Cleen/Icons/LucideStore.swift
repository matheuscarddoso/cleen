import CleenKit
import CoreText
import Foundation
import Synchronization

/// Lucide on disk and on the network. Each version lives in its own folder under
/// `~/Library/Application Support/Cleen/Lucide/<version>/`; a download fills a
/// `.partial` folder first and only takes the real name once every file arrived and
/// reads back, so a cut connection never leaves a half cache behind.
nonisolated enum LucideStore {
    enum Failure: Error {
        /// No connection, timeout, DNS.
        case offline
        /// The server answered, but not with what Lucide ships.
        case badResponse
    }

    /// What a version folder holds, read and ready to show.
    struct Library: Sendable {
        let version: String
        let folder: URL
        let index: LucideIndex
    }

    static let root = URL.applicationSupportDirectory
        .appending(path: "Cleen", directoryHint: .isDirectory)
        .appending(path: "Lucide", directoryHint: .isDirectory)

    static func folder(for version: String) -> URL {
        root.appending(path: version, directoryHint: .isDirectory)
    }

    static func fontURL(in folder: URL) -> URL {
        folder.appending(path: LucideSource.fontFile)
    }

    // MARK: Disk

    /// The complete version folders, newest first.
    static func installedVersions() -> [String] {
        folderNames()
            .filter { !$0.hasSuffix(".partial") && !$0.hasPrefix(".") && isComplete(folder(for: $0)) }
            .sorted { LucideSource.isNewer($0, than: $1) }
    }

    static func isComplete(_ folder: URL) -> Bool {
        LucideSource.files.allSatisfy { FileManager.default.fileExists(atPath: folder.appending(path: $0.local).path(percentEncoded: false)) }
    }

    /// Reads a version folder; nil when a file is missing or doesn't parse.
    static func read(version: String) -> Library? {
        let folder = folder(for: version)
        guard let info = try? Data(contentsOf: folder.appending(path: LucideSource.infoFile)),
              let tags = try? Data(contentsOf: folder.appending(path: LucideSource.tagsFile)),
              let icons = LucideCatalog.parse(info: info, tags: tags), !icons.isEmpty,
              fontName(at: fontURL(in: folder)) != nil
        else { return nil }
        return Library(version: version, folder: folder, index: LucideIndex(icons: icons))
    }

    /// Every other version goes once `version` is the one in use. Partial downloads are
    /// left to `download`, which may be filling one right now.
    static func removeVersions(except version: String) {
        for name in folderNames() where name != version && !name.hasSuffix(".partial") {
            try? FileManager.default.removeItem(at: root.appending(path: name, directoryHint: .isDirectory))
        }
    }

    private static func folderNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false))) ?? []
    }

    // MARK: Font

    /// The font's PostScript name, which is what SwiftUI asks for; nil if it isn't a font.
    static func fontName(at url: URL) -> String? {
        guard let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider)
        else { return nil }
        return font.postScriptName as String?
    }

    /// Makes the font available to this process only (nothing is installed system-wide)
    /// and returns its PostScript name.
    static func registerFont(at url: URL) -> String? {
        guard let name = fontName(at: url) else { return nil }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            // Registered already (a reload of the same version) is fine.
            guard code == CTFontManagerError.alreadyRegistered.rawValue else { return nil }
        }
        return name
    }

    static func unregisterFont(at url: URL) {
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
    }

    // MARK: Network

    /// The exact version `@latest` points to, read off unpkg's redirect.
    @concurrent
    static func latestVersion() async throws(Failure) -> String {
        var request = URLRequest(url: LucideSource.latestProbeURL, timeoutInterval: 15)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request, delegate: StopAtRedirect.shared)
        } catch {
            throw .offline
        }
        guard let http = response as? HTTPURLResponse else { throw .badResponse }
        let location = http.value(forHTTPHeaderField: "Location") ?? http.url?.absoluteString ?? ""
        guard let version = LucideSource.version(fromLocation: location) else { throw .badResponse }
        return version
    }

    /// Downloads one version's three files side by side, reporting 0...1 as they come in,
    /// and returns it read. The old version's folder isn't touched.
    @concurrent
    static func download(version: String, progress: @escaping @Sendable (Double) -> Void) async throws(Failure) -> Library {
        let final = folder(for: version)
        let partial = root.appending(path: "\(version).partial", directoryHint: .isDirectory)
        let created = await offMain { () -> Bool in
            let fileManager = FileManager.default
            // Only one download runs at a time, so any partial folder left is an abandoned one.
            for name in folderNames() where name.hasSuffix(".partial") {
                try? fileManager.removeItem(at: root.appending(path: name, directoryHint: .isDirectory))
            }
            return (try? fileManager.createDirectory(at: partial, withIntermediateDirectories: true)) != nil
        }
        guard created else { throw .badResponse }
        let cleanUp = { @Sendable in _ = await offMain { try? FileManager.default.removeItem(at: partial) } }

        let counter = ProgressCounter(report: progress)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for file in LucideSource.files {
                    group.addTask {
                        let url = LucideSource.fileURL(version: version, path: file.remote)
                        let data = try await fetch(url) { received, expected in counter.update(file.local, bytes: received, of: expected) }
                        let target = partial.appending(path: file.local)
                        let written = await offMain { (try? data.write(to: target, options: .atomic)) != nil }
                        if !written { throw Failure.badResponse }
                    }
                }
                try await group.waitForAll()
            }
        } catch let failure as Failure {
            await cleanUp()
            throw failure
        } catch {
            await cleanUp()
            throw .badResponse
        }

        // Moving it into place and reading it back (the parse takes a few dozen ms) stay
        // off the cooperative pool, like all disk work.
        let library = await offMain { () -> Library? in
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: final)
            guard (try? fileManager.moveItem(at: partial, to: final)) != nil else {
                try? fileManager.removeItem(at: partial)
                return nil
            }
            guard let library = read(version: version) else {
                try? fileManager.removeItem(at: final)
                return nil
            }
            return library
        }
        guard let library else { throw .badResponse }
        progress(1)
        return library
    }

    /// One icon's SVG, tidied for pasting. Fetched the first time, then kept next to the
    /// font so the same icon copies instantly (and offline) after that.
    @concurrent
    static func svg(for name: String, version: String) async throws(Failure) -> String {
        let cached = folder(for: version)
            .appending(path: "svg", directoryHint: .isDirectory)
            .appending(path: "\(name).svg")
        if let text = await offMain({ try? String(contentsOf: cached, encoding: .utf8) }), LucideSVG.looksLikeSVG(text) {
            return text
        }
        let data: Data
        do {
            data = try await fetch(LucideSource.svgURL(version: version, name: name), onProgress: nil)
        } catch let failure as Failure {
            throw failure
        } catch {
            throw .offline
        }
        guard let raw = String(data: data, encoding: .utf8), LucideSVG.looksLikeSVG(raw) else { throw .badResponse }
        let svg = LucideSVG.clean(raw)
        await offMain {
            try? FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? Data(svg.utf8).write(to: cached, options: .atomic)
        }
        return svg
    }

    /// A GET that must answer 200, read in chunks so the caller can show progress.
    private static func fetch(_ url: URL, onProgress: (@Sendable (_ received: Int, _ expected: Int?) -> Void)?) async throws -> Data {
        let request = URLRequest(url: url, timeoutInterval: 30)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw Failure.offline
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.badResponse }
        let expected = response.expectedContentLength > 0 ? Int(response.expectedContentLength) : nil
        var data = Data()
        data.reserveCapacity(expected ?? 64 * 1024)
        var sinceReport = 0
        do {
            for try await byte in bytes {
                data.append(byte)
                sinceReport += 1
                if sinceReport >= 32 * 1024 {
                    sinceReport = 0
                    onProgress?(data.count, expected)
                }
            }
        } catch {
            throw Failure.offline
        }
        onProgress?(data.count, expected)
        return data
    }
}

/// Keeps a request from following redirects, so `@latest` hands back where it points
/// instead of the file itself.
private nonisolated final class StopAtRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = StopAtRedirect()

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

/// Adds the three files' bytes up against their sizes: the real one when the server
/// says it, the usual one otherwise. Short of done it never claims more than 97%.
private nonisolated final class ProgressCounter: Sendable {
    private struct File {
        var received = 0
        var expected: Int
    }

    private let state = Mutex<[String: File]>([:])
    private let report: @Sendable (Double) -> Void

    init(report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func update(_ file: String, bytes: Int, of expected: Int?) {
        let fraction = state.withLock { files in
            files[file] = File(received: bytes, expected: expected ?? LucideSource.expectedBytes[file] ?? bytes)
            var received = 0, total = 0
            for (name, usual) in LucideSource.expectedBytes {
                let entry = files[name] ?? File(expected: usual)
                received += min(entry.received, entry.expected)
                total += entry.expected
            }
            return total > 0 ? min(Double(received) / Double(total), 0.97) : 0
        }
        report(fraction)
    }
}
