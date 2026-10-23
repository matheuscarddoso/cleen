import Foundation

/// How a candidate leaves the disk.
public enum RemovalMode: Sendable, Hashable {
    /// Gone for good. Used only for things that regenerate on their own: caches, logs,
    /// build output. Moving those to the Trash wouldn't free a single byte.
    case delete
    /// Recoverable from the Trash. Used for anything the person made or chose to keep.
    case trash
}

public struct RemovalRequest: Sendable, Hashable {
    public let url: URL
    public let size: Int64
    public let mode: RemovalMode

    public init(url: URL, size: Int64, mode: RemovalMode) {
        self.url = url
        self.size = size
        self.mode = mode
    }
}

public struct RemovalFailure: Sendable, Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let reason: String

    public init(url: URL, reason: String) {
        self.url = url
        self.reason = reason
    }
}

public struct RemovalOutcome: Sendable {
    public var freed: Int64 = 0
    public var trashed: Int64 = 0
    public var removed: [URL] = []
    public var failures: [RemovalFailure] = []

    public init() {}

    public mutating func merge(_ other: RemovalOutcome) {
        freed += other.freed
        trashed += other.trashed
        removed += other.removed
        failures += other.failures
    }
}

public struct FileRemover: Sendable {
    let safety: SafetyGuard

    public static let standard = FileRemover(safety: .standard)

    public init(safety: SafetyGuard) {
        self.safety = safety
    }

    /// Removes every request it can and reports the rest. Never throws: one locked file
    /// must not stop a cleanup of thousands.
    public func remove(_ requests: [RemovalRequest]) async -> RemovalOutcome {
        var outcome = RemovalOutcome()
        let manager = FileManager()
        for request in requests {
            if Task.isCancelled { break }
            do {
                let url = try safety.validate(request.url)
                guard FileSizer.exists(url) else {
                    // Already gone (an app cleaned its own cache). Nothing was freed by us.
                    outcome.removed.append(request.url)
                    continue
                }
                switch request.mode {
                case .delete:
                    try manager.removeItem(at: url)
                    outcome.freed += request.size
                case .trash:
                    try manager.trashItem(at: url, resultingItemURL: nil)
                    outcome.trashed += request.size
                }
                outcome.removed.append(request.url)
            } catch {
                outcome.failures.append(RemovalFailure(url: request.url, reason: Self.describe(error)))
            }
        }
        return outcome
    }

    /// Removes root-owned items (an app installed by a .pkg, a system launch daemon) with
    /// one authorization prompt for the whole batch.
    /// `preamble` runs first in the same privileged shell (e.g. stopping a daemon).
    public func removeAsAdministrator(_ requests: [RemovalRequest], preamble: String? = nil) async -> RemovalOutcome {
        var outcome = RemovalOutcome()
        var validated: [(RemovalRequest, URL)] = []
        for request in requests {
            do {
                validated.append((request, try safety.validate(request.url)))
            } catch {
                outcome.failures.append(RemovalFailure(url: request.url, reason: Self.describe(error)))
            }
        }
        guard !validated.isEmpty else { return outcome }

        let trash = safety.home + "/.Trash/"
        let commands = validated.map { request, url in
            switch request.mode {
            case .delete:
                "/bin/rm -rf \(Shell.quote(url.path(percentEncoded: false)))"
            case .trash:
                // Keep the item recoverable and hand it back to the user so they can empty it.
                "/bin/mv -f \(Shell.quote(url.path(percentEncoded: false))) \(Shell.quote(trash + Self.trashName(for: url))) && /usr/sbin/chown -R \(getuid()) \(Shell.quote(trash + Self.trashName(for: url)))"
            }
        }
        do {
            _ = try await Shell.runAsAdministrator(([preamble].compactMap { $0 } + commands).joined(separator: " ; "))
        } catch {
            let reason = error.localizedDescription
            outcome.failures += validated.map { RemovalFailure(url: $0.0.url, reason: reason) }
            return outcome
        }

        for (request, url) in validated {
            if FileSizer.exists(url) {
                outcome.failures.append(RemovalFailure(url: request.url, reason: String(localized: "Continua no lugar depois da remoção.")))
            } else {
                outcome.removed.append(request.url)
                if request.mode == .delete { outcome.freed += request.size } else { outcome.trashed += request.size }
            }
        }
        return outcome
    }

    /// A name that won't collide with something already in the Trash.
    static func trashName(for url: URL) -> String {
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacing(":", with: "-")
        return "\(url.deletingPathExtension().lastPathComponent) \(stamp)"
            + (url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)")
    }

    /// Matched by value in `isPermissionFailure`, so it's built once per launch, in one language.
    static let permissionReason = String(localized: "Sem permissão. Pode exigir senha de administrador ou Acesso Total ao Disco.")

    static func describe(_ error: any Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(nsError.code) {
            return permissionReason
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain, underlying.code == Int(EPERM) || underlying.code == Int(EACCES) {
            return permissionReason
        }
        return error.localizedDescription
    }

    /// Whether a failure is a permission problem worth retrying with administrator rights.
    public static func isPermissionFailure(_ failure: RemovalFailure) -> Bool {
        failure.reason == permissionReason
    }
}
