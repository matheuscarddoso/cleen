import CoreGraphics
import Foundation

/// A recording as the editor opens it: a folder holding the screen video, the camera
/// video (if any), the pointer's track and this manifest (`project.json`) with the edits.
public struct RecordingProject: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable {
        case display, window, area, device
    }

    /// The screen movie's sound tracks, in the order they were written.
    public enum AudioSource: String, Codable, Sendable {
        case system, microphone
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
    public var audio: [AudioSource]
    public var style: EditorStyle
    public var zoom: [ZoomSegment]
    /// What's kept and how fast, in order: the timeline's clips.
    public var clips: [ClipSegment]
    /// The part of the recording shown, 0…1 with a top-left origin; nil is all of it.
    public var crop: CGRect?
    public var export: ExportOptions

    public init(createdAt: Date = .now, source: Source, sourceSize: CGSize, duration: Double, hasCamera: Bool, audio: [AudioSource] = [],
                style: EditorStyle = EditorStyle(), zoom: [ZoomSegment] = [], export: ExportOptions = ExportOptions()) {
        self.createdAt = createdAt
        self.source = source
        self.sourceSize = sourceSize
        self.duration = duration
        self.hasCamera = hasCamera
        self.audio = audio
        self.style = style
        self.zoom = zoom
        self.clips = [ClipSegment(start: 0, end: duration)]
        self.crop = nil
        self.export = export
    }

    private enum CodingKeys: String, CodingKey {
        case version, createdAt, source, sourceSize, duration, hasCamera, audio, style, zoom, clips, crop, export
        // Before clips: one trimmed stretch.
        case trimStart, trimEnd
    }

    /// Projects from earlier versions open too: what they lack takes its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        source = try c.decode(Source.self, forKey: .source)
        sourceSize = try c.decode(CGSize.self, forKey: .sourceSize)
        duration = try c.decode(Double.self, forKey: .duration)
        hasCamera = try c.decodeIfPresent(Bool.self, forKey: .hasCamera) ?? false
        audio = try c.decodeIfPresent([AudioSource].self, forKey: .audio) ?? []
        style = try c.decodeIfPresent(EditorStyle.self, forKey: .style) ?? EditorStyle()
        zoom = try c.decodeIfPresent([ZoomSegment].self, forKey: .zoom) ?? []
        crop = try c.decodeIfPresent(CGRect.self, forKey: .crop)
        export = try c.decodeIfPresent(ExportOptions.self, forKey: .export) ?? ExportOptions()
        if let clips = try c.decodeIfPresent([ClipSegment].self, forKey: .clips), !clips.isEmpty {
            self.clips = clips
        } else {
            let start = try c.decodeIfPresent(Double.self, forKey: .trimStart) ?? 0
            let end = try c.decodeIfPresent(Double.self, forKey: .trimEnd) ?? duration
            clips = [ClipSegment(start: start, end: max(start + 0.1, end))]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(source, forKey: .source)
        try c.encode(sourceSize, forKey: .sourceSize)
        try c.encode(duration, forKey: .duration)
        try c.encode(hasCamera, forKey: .hasCamera)
        try c.encode(audio, forKey: .audio)
        try c.encode(style, forKey: .style)
        try c.encode(zoom, forKey: .zoom)
        try c.encode(clips, forKey: .clips)
        try c.encodeIfPresent(crop, forKey: .crop)
        try c.encode(export, forKey: .export)
    }

    /// The finished video's clock.
    public var timeline: EditTimeline { EditTimeline(clips: clips) }

    /// The part of the recording that's shown, in points.
    public var croppedSize: CGSize {
        guard let crop else { return sourceSize }
        return CGSize(width: sourceSize.width * crop.width, height: sourceSize.height * crop.height)
    }

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
