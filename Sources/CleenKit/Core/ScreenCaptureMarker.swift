import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Recognizes a screenshot or a screen recording by what the system writes inside the file.
///
/// The screenshot service marks each capture twice. The `kMDItemIsScreenCapture` tag goes
/// through Spotlight's metadata service, a moment after the file lands, and never arrives
/// while the volume's Spotlight index is broken. It also marks the file's own contents,
/// so that mark is there the moment the file is, whatever state Spotlight is in: a
/// screenshot carries "Screenshot" as its EXIF user comment, a recording (⌘⇧5, the
/// Screenshot app, `screencapture -v`) "ReplayKitRecording" as its QuickTime author.
public enum ScreenCaptureMarker {
    /// The EXIF user comment on every screenshot.
    public static let comment = "Screenshot"
    /// The QuickTime author on every screen recording: the system records through ReplayKit.
    public static let recordingAuthor = "ReplayKitRecording"

    /// A movie, by its extension: recordings are read through AVFoundation, images
    /// through ImageIO.
    public static func isMovie(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true
    }

    /// Either kind. Reads only the file's metadata, never its pixels or frames: cheap
    /// enough for every new file in a folder.
    public static func isPresent(at url: URL) async -> Bool {
        isMovie(url) ? await isPresent(inMovieAt: url) : isPresent(inImageAt: url)
    }

    /// A screenshot's mark, read synchronously.
    public static func isPresent(inImageAt url: URL) -> Bool {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let userComment = exif[kCGImagePropertyExifUserComment] as? String
        else { return false }
        return userComment == comment
    }

    /// A recording's mark: the QuickTime metadata sits in the movie's header.
    public static func isPresent(inMovieAt url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.loadMetadata(for: .quickTimeMetadata) else { return false }
        for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .quickTimeMetadataAuthor) {
            if (try? await item.load(.stringValue)) == recordingAuthor { return true }
        }
        return false
    }
}
