import CleenKit
import Foundation
import Synchronization

/// Runs the Now Playing helper (`/usr/bin/perl` + `libCleenNowPlaying.dylib`, see
/// Support/NowPlaying) and turns its stream of JSON lines into readings.
nonisolated final class NowPlayingBridge: Sendable {
    /// One line: what's playing (nil for nothing) and its artwork, when the line carries it.
    typealias Update = @MainActor @Sendable (NowPlayingTrack?, Data?) -> Void

    private let process = Mutex<Process?>(nil)
    private let buffer = Mutex(Data())

    static var library: URL? { Bundle.main.url(forResource: "libCleenNowPlaying", withExtension: "dylib") }
    static var driver: URL? { Bundle.main.url(forResource: "now-playing", withExtension: "pl") }
    static var isAvailable: Bool { library != nil && driver != nil }

    /// Starts streaming. `onUpdate` runs on the main actor for every line, in the order
    /// the helper wrote them (the main queue is FIFO, so an older reading can never land
    /// after a newer one). `onExit` runs on the main actor if the helper dies, after its
    /// last line.
    func start(onUpdate: @escaping Update, onExit: @escaping @MainActor @Sendable () -> Void) {
        guard let library = Self.library, let driver = Self.driver else { return }
        process.withLock { current in
            guard current == nil else { return }
            // A line cut short by a helper that died must not prefix the new one's first.
            buffer.withLock { $0.removeAll() }
            let helper = Process()
            helper.executableURL = URL(filePath: "/usr/bin/perl")
            helper.arguments = [driver.path(percentEncoded: false), library.path(percentEncoded: false), "cleen_stream"]
            let pipe = Pipe()
            helper.standardOutput = pipe
            helper.standardError = FileHandle.nullDevice
            // The pipe's end and the process's exit come on different threads, in either
            // order. Lines are posted as they're read, so only once the pipe has ended too
            // are they all ahead of the exit on the main queue; whichever comes second
            // reports it.
            let ending = Mutex(Ending())
            let reportExit: @Sendable () -> Void = { DispatchQueue.main.async { MainActor.assumeIsolated { onExit() } } }
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else {
                    handle.readabilityHandler = nil
                    if ending.withLock({ $0.pipeClosed = true; return $0.crashed == true }) { reportExit() }
                    return
                }
                self?.consume(chunk, onUpdate: onUpdate)
            }
            helper.terminationHandler = { [weak self] ended in
                let crashed = self?.forget(ended) == true
                if ending.withLock({ $0.crashed = crashed; return crashed && $0.pipeClosed }) { reportExit() }
            }
            guard (try? helper.run()) != nil else { return }
            current = helper
        }
    }

    func stop() {
        process.withLock { current in
            let helper = current
            current = nil
            helper?.terminate()
        }
    }

    /// Fire-and-forget media command through the same helper.
    static func send(_ command: NowPlayingCommand) async {
        guard let library, let driver else { return }
        let helper = Process()
        helper.executableURL = URL(filePath: "/usr/bin/perl")
        helper.arguments = [driver.path(percentEncoded: false), library.path(percentEncoded: false), "cleen_send"]
        helper.environment = ["CLEEN_COMMAND": String(command.rawValue)]
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        let exit = AsyncStream<Void> { continuation in
            helper.terminationHandler = { _ in continuation.finish() }
        }
        guard (try? helper.run()) != nil else { return }
        for await _ in exit {}
    }

    /// How far a helper has got in ending; see `start`.
    private struct Ending {
        var pipeClosed = false
        /// nil while it's still running; false when it was stopped on purpose.
        var crashed: Bool?
    }

    /// Clears the running helper if it's `ended`; false when it was stopped on purpose
    /// (or already replaced), so only a crash is reported.
    private func forget(_ ended: Process) -> Bool {
        process.withLock { current in
            guard current === ended else { return false }
            current = nil
            return true
        }
    }

    private func consume(_ chunk: Data, onUpdate: @escaping Update) {
        let lines: [Data] = buffer.withLock { pending in
            pending.append(chunk)
            var complete: [Data] = []
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                complete.append(pending[pending.startIndex..<newline])
                pending.removeSubrange(pending.startIndex...newline)
            }
            return complete
        }
        for line in lines {
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            let track = NowPlayingTrack(json: json)
            let artwork = (json["artwork"] as? String).flatMap { Data(base64Encoded: $0) }
            DispatchQueue.main.async { MainActor.assumeIsolated { onUpdate(track, artwork) } }
        }
    }
}
