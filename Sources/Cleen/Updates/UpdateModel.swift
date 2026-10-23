import AppKit
import CleenKit
import CryptoKit
import Observation
import Security

/// Keeps Cleen current: checks a small feed published with each release, and when
/// there's a newer version downloads it, checks it's intact and signed by the same
/// developer as the copy running, swaps the app in place and reopens it. The old
/// copy goes to the Lixo, so a bad update is one drag away from undone.
@Observable
final class UpdateModel {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateFeed)
        case downloading
        case installing
        case failed(String)
    }

    private(set) var phase = Phase.idle

    /// Published with every release by `scripts/release.sh`.
    static let feedURL = URL(string: "https://github.com/matheuscarddoso/cleen/releases/latest/download/appcast.json")!
    static let automaticKey = "updatesAutomatic"
    private static let interval: Duration = .seconds(6 * 3600)

    @ObservationIgnored private var loop: Task<Void, Never>?

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var available: UpdateFeed? {
        if case .available(let feed) = phase { return feed }
        return nil
    }

    /// Checks a minute after launch, then every six hours, unless turned off.
    func start() {
        UserDefaults.standard.register(defaults: [Self.automaticKey: true])
        guard loop == nil else { return }
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            while !Task.isCancelled {
                if UserDefaults.standard.bool(forKey: Self.automaticKey) { await self?.check() }
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func check() async {
        guard phase != .checking, phase != .downloading, phase != .installing else { return }
        phase = .checking
        do {
            var request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("Cleen/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.unreachable }
            let feed = try JSONDecoder().decode(UpdateFeed.self, from: data)
            phase = feed.isUpdate(over: Self.currentVersion) ? .available(feed) : .upToDate
        } catch {
            phase = .failed(String(localized: "Não deu para procurar atualizações agora."))
        }
    }

    /// Downloads, verifies and installs the available version, then relaunches.
    func install() async {
        guard let feed = available else { return }
        phase = .downloading
        do {
            let (download, _) = try await URLSession.shared.download(from: feed.url)
            phase = .installing
            let destination = Bundle.main.bundleURL
            let failure: (any Error)? = await offMain {
                do {
                    try Installer.install(dmg: download, sha256: feed.sha256, replacing: destination)
                    return nil
                } catch {
                    return error
                }
            }
            if let failure { throw failure }
            Installer.relaunch(destination)
        } catch let error as UpdateError {
            phase = .failed(error.message)
        } catch {
            phase = .failed(String(localized: "A atualização não terminou: \(error.localizedDescription)"))
        }
    }
}

enum UpdateError: Error {
    case unreachable
    case damaged
    case untrusted
    case noApp

    var message: String {
        switch self {
        case .unreachable: String(localized: "Não deu para procurar atualizações agora.")
        case .damaged: String(localized: "O arquivo baixado veio corrompido. Nada foi trocado.")
        case .untrusted: String(localized: "A nova versão não tem a mesma assinatura desta. Nada foi trocado.")
        case .noApp: String(localized: "O arquivo baixado não tem o Cleen dentro. Nada foi trocado.")
        }
    }
}

/// The blocking part of an update, off the main thread.
nonisolated enum Installer {
    static func install(dmg: URL, sha256: String, replacing destination: URL) throws {
        // 1. Intact: the hash the release published.
        let digest = SHA256.hash(data: try Data(contentsOf: dmg, options: .mappedIfSafe))
        guard digest.map({ String(format: "%02x", $0) }).joined() == sha256.lowercased() else { throw UpdateError.damaged }

        // 2. Opened read-only somewhere private.
        let mount = FileManager.default.temporaryDirectory.appending(path: "cleen-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", dmg.path(percentEncoded: false), "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path(percentEncoded: false)])
        defer { try? run("/usr/bin/hdiutil", ["detach", mount.path(percentEncoded: false), "-force"]) }
        let incoming = mount.appending(path: "Cleen.app")
        guard FileManager.default.fileExists(atPath: incoming.path(percentEncoded: false)) else { throw UpdateError.noApp }

        // 3. Signed, and by the same team as the copy running.
        guard let team = teamIdentifier(of: Bundle.main.bundleURL), teamIdentifier(of: incoming) == team, isValidSignature(incoming) else {
            throw UpdateError.untrusted
        }

        // 4. Staged beside the old copy, then swapped; the old copy goes to the Lixo.
        let staged = destination.deletingLastPathComponent().appending(path: ".Cleen-update.app")
        try? FileManager.default.removeItem(at: staged)
        try run("/usr/bin/ditto", [incoming.path(percentEncoded: false), staged.path(percentEncoded: false)])
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path(percentEncoded: false)])
        var trashed: NSURL?
        try FileManager.default.trashItem(at: destination, resultingItemURL: &trashed)
        do {
            try FileManager.default.moveItem(at: staged, to: destination)
        } catch {
            // Put the old one back rather than leave no Cleen at all.
            if let trashed = trashed as URL? { try? FileManager.default.moveItem(at: trashed, to: destination) }
            throw error
        }
    }

    /// Opens the new copy a moment after this one quits.
    @MainActor static func relaunch(_ app: URL) {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path(percentEncoded: false)]
        try? process.run()
        NSApp.terminate(nil)
    }

    static func teamIdentifier(of app: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any]
        else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }

    static func isValidSignature(_ app: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return false }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode), nil) == errSecSuccess
    }

    private static func run(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.noApp }
    }
}
