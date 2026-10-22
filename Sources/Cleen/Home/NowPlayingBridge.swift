import Foundation
import Synchronization

/// Runs the Now Playing helper (`/usr/bin/perl` + `libCleenNowPlaying.dylib`, see
/// Support/NowPlaying) and turns its stream of JSON lines into dictionaries.
nonisolated final class NowPlayingBridge: Sendable {
    private let process = Mutex<Process?>(nil)
    private let buffer = Mutex(Data())

    static var library: URL? { Bundle.main.url(forResource: "libCleenNowPlaying", withExtension: "dylib") }
    static var driver: URL? { Bundle.main.url(forResource: "now-playing", withExtension: "pl") }
    static var isAvailable: Bool { library != nil && driver != nil }

    /// Starts streaming; `onUpdate` runs on a background queue for every line.
    func start(onUpdate: @escaping @Sendable ([String: Any]) -> Void) {
        guard let library = Self.library, let driver = Self.driver else { return }
        process.withLock { current in
            guard current == nil else { return }
            let helper = Process()
            helper.executableURL = URL(filePath: "/usr/bin/perl")
            helper.arguments = [driver.path(percentEncoded: false), library.path(percentEncoded: false), "cleen_stream"]
            let pipe = Pipe()
            helper.standardOutput = pipe
            helper.standardError = FileHandle.nullDevice
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                self?.consume(chunk, onUpdate: onUpdate)
            }
            try? helper.run()
            current = helper
        }
    }

    func stop() {
        process.withLock { current in
            current?.terminate()
            current = nil
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

    private func consume(_ chunk: Data, onUpdate: @Sendable ([String: Any]) -> Void) {
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
            if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                onUpdate(object)
            }
        }
    }
}
