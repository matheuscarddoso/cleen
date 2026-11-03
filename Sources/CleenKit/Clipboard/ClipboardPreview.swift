import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// What a clipboard card shows as its picture, decided from the entry alone, without
/// touching the disk: the image the log saved, a copied image file decoded as it is,
/// or any other file as Quick Look renders it.
public struct ClipboardPreview: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// Image data that was on the pasteboard, saved by the log under this file name.
        case storedImage(fileName: String)
        /// A copied file that is an image: decoded directly, at the card's size.
        case imageFile(path: String)
        /// Any other copied file: a PDF's first page, a movie's frame, and so on.
        case quickLook(path: String)
    }

    /// Which part of the picture survives when it's cropped to fill the card.
    public enum Anchor: Equatable, Sendable {
        /// Photos and movies: the subject is usually in the middle.
        case center
        /// Documents: the title and the first lines are at the top of the page.
        case top
    }

    public let source: Source

    public init(source: Source) {
        self.source = source
    }

    public var anchor: Anchor {
        guard case let .quickLook(path) = source else { return .center }
        let type = UTType(filenameExtension: URL(filePath: path).pathExtension)
        return type?.conforms(to: .audiovisualContent) == true ? .center : .top
    }

    /// The cache key for one rendering: the entry and the exact pixels it was drawn at,
    /// so the same card at the same size never renders twice.
    public static func cacheKey(id: UUID, size: CGSize, scale: CGFloat) -> String {
        let pixels = pixelSize(for: size, scale: scale)
        return "\(id.uuidString)|\(pixels.width)x\(pixels.height)"
    }

    /// Whole pixels a frame of `size` points covers at `scale`, rounded up so the
    /// picture is never drawn softer than the screen.
    public static func pixelSize(for size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        let scale = max(scale, 1)
        return (Int((max(size.width, 0) * scale).rounded(.up)), Int((max(size.height, 0) * scale).rounded(.up)))
    }

    /// The square Quick Look is asked to fit its thumbnail into, for a picture that
    /// will be cropped to fill `size`. Quick Look keeps the file's proportions inside
    /// the box it's given; twice the longest side covers anything from a 1:2 portrait
    /// page or movie to a 2:1 panorama without being stretched up.
    public static func quickLookSide(toFill size: CGSize) -> CGFloat {
        max(size.width, size.height, 0) * 2
    }
}

public extension ClipboardEntry {
    /// The picture this entry's card shows, or nil when it is words.
    var preview: ClipboardPreview? {
        switch kind {
        case .text, .link:
            return nil
        case .image:
            return imageFile.map { ClipboardPreview(source: .storedImage(fileName: $0)) }
        case .files:
            guard let path = files?.first, !path.isEmpty else { return nil }
            let type = UTType(filenameExtension: URL(filePath: path).pathExtension)
            return ClipboardPreview(source: type?.conforms(to: .image) == true ? .imageFile(path: path) : .quickLook(path: path))
        }
    }
}
