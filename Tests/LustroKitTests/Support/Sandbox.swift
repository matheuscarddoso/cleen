import Foundation

/// A throwaway folder that plays the part of a home directory.
final class Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "lustro-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func url(_ path: String) -> URL {
        root.appending(path: path)
    }

    @discardableResult
    func file(_ path: String, bytes: Int = 4096, fill: UInt8 = 0x41) throws -> URL {
        let url = url(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: fill, count: bytes).write(to: url)
        return url
    }

    @discardableResult
    func folder(_ path: String) throws -> URL {
        let url = url(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: url(path).path(percentEncoded: false))
    }
}
