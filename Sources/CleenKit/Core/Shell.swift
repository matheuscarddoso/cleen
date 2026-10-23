import Foundation
import Synchronization

public struct ShellResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var succeeded: Bool { status == 0 }
}

public enum ShellError: Error, LocalizedError {
    case launchFailed(String)
    case cancelledByUser
    case failed(ShellResult)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message): String(localized: "Não foi possível executar: \(message)")
        case .cancelledByUser: String(localized: "Autorização cancelada.")
        case .failed(let result):
            result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? String(localized: "O comando terminou com código \(result.status).")
        }
    }
}

public enum Shell {
    /// Runs an executable directly (no shell, no string interpolation into a command line)
    /// and collects its output. Cancelling the calling task terminates the process.
    public static func run(_ executable: String, _ arguments: [String] = []) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        let exit = AsyncStream<Int32> { continuation in
            process.terminationHandler = { finished in
                continuation.yield(finished.terminationStatus)
                continuation.finish()
            }
        }

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        let running = process
        return await withTaskCancellationHandler {
            // Drain both pipes concurrently so a chatty process can't fill one and block.
            async let stdout = collect(out.fileHandleForReading)
            async let stderr = collect(err.fileHandleForReading)
            let output = await (stdout, stderr)
            var status: Int32 = -1
            for await code in exit { status = code }
            return ShellResult(status: status, stdout: output.0, stderr: output.1)
        } onCancel: {
            if running.isRunning { running.terminate() }
        }
    }

    /// Runs a fixed command with root privileges through the standard macOS
    /// authorization prompt. Only call this with commands built from constants and
    /// paths quoted by ``quote(_:)``.
    public static func runAsAdministrator(_ command: String) async throws -> ShellResult {
        let escaped = command
            .replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let result = try await run("/usr/bin/osascript", ["-e", script])
        if result.stderr.contains("-128") { throw ShellError.cancelledByUser }
        guard result.succeeded else { throw ShellError.failed(result) }
        return result
    }

    /// Single-quotes a value for `/bin/sh`.
    public static func quote(_ value: String) -> String {
        "'" + value.replacing("'", with: "'\\''") + "'"
    }

    /// Reads a pipe to EOF without tying up a thread.
    ///
    /// `FileHandle.bytes` serializes reads from every handle in the process through one
    /// actor: while it sits in a blocking read on an idle stderr, nobody drains stdout, the
    /// child fills the 64 KB pipe buffer and both sides wait forever (`launchctl print`
    /// does exactly that). A readability handler is driven by a dispatch source instead.
    private static func collect(_ handle: FileHandle) async -> String {
        let buffer = OutputBuffer()
        return await withCheckedContinuation { continuation in
            handle.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard chunk.isEmpty else {
                    buffer.append(chunk)
                    return
                }
                handle.readabilityHandler = nil
                continuation.resume(returning: buffer.text)
            }
        }
    }
}

/// Bytes collected from a pipe, appended from the handle's dispatch queue.
private final class OutputBuffer: Sendable {
    private let data = Mutex(Data())

    func append(_ chunk: Data) {
        data.withLock { $0.append(chunk) }
    }

    var text: String {
        data.withLock { String(decoding: $0, as: UTF8.self) }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
