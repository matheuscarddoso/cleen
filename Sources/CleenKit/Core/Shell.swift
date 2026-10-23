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
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message): String(localized: "Não foi possível executar: \(message)")
        case .cancelledByUser: String(localized: "Autorização cancelada.")
        case .timedOut: String(localized: "O comando demorou demais e foi interrompido.")
        case .failed(let result):
            result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? String(localized: "O comando terminou com código \(result.status).")
        }
    }
}

public enum Shell {
    /// Runs an executable directly (no shell, no string interpolation into a command line)
    /// and collects its output. Cancelling the calling task terminates the process.
    ///
    /// With a `timeout`, a process that hasn't finished by then is terminated (killed if it
    /// ignores that) and the call throws ``ShellError/timedOut``: a CLI stuck waiting on a
    /// daemon that never answers (`docker` with a wedged engine) must not hang its caller.
    public static func run(_ executable: String, _ arguments: [String] = [], timeout: Duration? = nil) async throws -> ShellResult {
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
        let stdoutReader = PipeReader(out.fileHandleForReading)
        let stderrReader = PipeReader(err.fileHandleForReading)
        // Answers whether it had to step in.
        let watchdog = timeout.map { limit in
            Task.detached { () -> Bool in
                try? await Task.sleep(for: limit)
                guard !Task.isCancelled, running.isRunning else { return false }
                running.terminate()
                try? await Task.sleep(for: .seconds(1))
                if running.isRunning { kill(running.processIdentifier, SIGKILL) }
                // A child the process spawned can keep the pipes open after it's gone;
                // stop waiting for their end-of-file.
                stdoutReader.finish()
                stderrReader.finish()
                return true
            }
        }

        let result = await withTaskCancellationHandler {
            // Drain both pipes concurrently so a chatty process can't fill one and block.
            async let stdout = stdoutReader.text()
            async let stderr = stderrReader.text()
            let output = await (stdout, stderr)
            var status: Int32 = -1
            for await code in exit { status = code }
            return ShellResult(status: status, stdout: output.0, stderr: output.1)
        } onCancel: {
            if running.isRunning { running.terminate() }
        }
        if let watchdog {
            watchdog.cancel()
            if await watchdog.value { throw ShellError.timedOut }
        }
        return result
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
}

/// Reads a pipe to EOF without tying up a thread.
///
/// `FileHandle.bytes` serializes reads from every handle in the process through one
/// actor: while it sits in a blocking read on an idle stderr, nobody drains stdout, the
/// child fills the 64 KB pipe buffer and both sides wait forever (`launchctl print`
/// does exactly that). A readability handler is driven by a dispatch source instead.
private final class PipeReader: Sendable {
    private struct State {
        var data = Data()
        var continuation: CheckedContinuation<String, Never>?
        var finished = false
    }

    private let handle: FileHandle
    private let state = Mutex(State())

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    /// Everything read until end-of-file, or until ``finish()`` stops the wait.
    func text() async -> String {
        await withCheckedContinuation { continuation in
            let done = state.withLock { state -> String? in
                if state.finished { return String(decoding: state.data, as: UTF8.self) }
                state.continuation = continuation
                return nil
            }
            if let done { return continuation.resume(returning: done) }
            handle.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                guard let self else { return }
                if chunk.isEmpty { self.finish() } else { self.state.withLock { $0.data.append(chunk) } }
            }
        }
    }

    /// Stops reading and hands back what arrived so far. Safe to call more than once.
    func finish() {
        handle.readabilityHandler = nil
        let pending = state.withLock { state -> (continuation: CheckedContinuation<String, Never>, text: String)? in
            guard !state.finished else { return nil }
            state.finished = true
            defer { state.continuation = nil }
            return state.continuation.map { ($0, String(decoding: state.data, as: UTF8.self)) }
        }
        if let pending { pending.continuation.resume(returning: pending.text) }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
