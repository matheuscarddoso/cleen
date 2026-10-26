import CoreGraphics
import Foundation

/// A recording as the editor opens it: a folder holding the screen video, the camera
/// video (if any), the pointer's track and this manifest (`project.json`) with the edits.
public struct RecordingProject: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable {
        case display, window, area, device
    }

    public static let manifestName = "project.json"
    public static let screenName = "screen.mov"
    public static let cameraName = "camera.mov"
    public static let cursorName = "cursor.json"
    public static let folderExtension = "cleenrec"

    public var version = 1
    public var createdAt: Date
    public var source: Source
    /// The recorded area, in points.
    public var sourceSize: CGSize
    /// Seconds.
    public var duration: Double
    public var hasCamera: Bool
    public var style: EditorStyle
    public var zoom: [ZoomSegment]
    /// What's kept, in seconds from the start.
    public var trimStart: Double
    public var trimEnd: Double
    public var export: ExportOptions

    public init(createdAt: Date = .now, source: Source, sourceSize: CGSize, duration: Double, hasCamera: Bool,
                style: EditorStyle = EditorStyle(), zoom: [ZoomSegment] = [], export: ExportOptions = ExportOptions()) {
        self.createdAt = createdAt
        self.source = source
        self.sourceSize = sourceSize
        self.duration = duration
        self.hasCamera = hasCamera
        self.style = style
        self.zoom = zoom
        self.trimStart = 0
        self.trimEnd = duration
        self.export = export
    }

    /// The kept length.
    public var trimmedDuration: Double { max(0, trimEnd - trimStart) }

    // MARK: Files

    public static func load(from folder: URL) throws -> RecordingProject {
        let data = try Data(contentsOf: folder.appending(path: manifestName))
        return try JSONDecoder().decode(RecordingProject.self, from: data)
    }

    public func save(to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: folder.appending(path: Self.manifestName), options: .atomic)
    }

    public static func loadCursor(from folder: URL) -> CursorTrack {
        guard let data = try? Data(contentsOf: folder.appending(path: cursorName)) else { return CursorTrack() }
        return (try? JSONDecoder().decode(CursorTrack.self, from: data)) ?? CursorTrack()
    }

    /// "Gravação 2026-10-26 às 13.45.12.cleenrec"-style name, unique in `folder`.
    public static func newFolder(in folder: URL, date: Date = .now, prefix: String) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "\(prefix) \(formatter.string(from: date))"
        var candidate = folder.appending(path: "\(base).\(folderExtension)", directoryHint: .isDirectory)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = folder.appending(path: "\(base) \(n).\(folderExtension)", directoryHint: .isDirectory)
            n += 1
        }
        return candidate
    }
}
