import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CleenKit

@Suite struct ScreenCaptureMarkerTests {
    // MARK: Screenshots

    @Test func recognizesTheCommentTheScreenshotServiceWrites() async throws {
        let sandbox = try Sandbox()
        let png = try Self.image(at: sandbox.url("Screenshot.png"), type: .png, comment: "Screenshot")
        let jpeg = try Self.image(at: sandbox.url("Screenshot.jpg"), type: .jpeg, comment: "Screenshot")
        #expect(ScreenCaptureMarker.isPresent(inImageAt: png))
        #expect(ScreenCaptureMarker.isPresent(inImageAt: jpeg))
        #expect(await ScreenCaptureMarker.isPresent(at: png))
    }

    @Test func anyOtherImageIsNotACapture() throws {
        let sandbox = try Sandbox()
        let plain = try Self.image(at: sandbox.url("photo.png"), type: .png, comment: nil)
        let commented = try Self.image(at: sandbox.url("edited.png"), type: .png, comment: "Exported from Preview")
        #expect(!ScreenCaptureMarker.isPresent(inImageAt: plain))
        #expect(!ScreenCaptureMarker.isPresent(inImageAt: commented))
    }

    @Test func filesThatAreNotImagesOrAreGoneAreNot() async throws {
        let sandbox = try Sandbox()
        let text = try sandbox.file("notes.png", bytes: 64)
        #expect(!ScreenCaptureMarker.isPresent(inImageAt: text))
        #expect(!ScreenCaptureMarker.isPresent(inImageAt: sandbox.url("missing.png")))
        #expect(await !ScreenCaptureMarker.isPresent(at: sandbox.url("missing.mov")))
    }

    // MARK: Screen recordings

    @Test func recognizesTheAuthorOfTheSystemsRecordings() async throws {
        let sandbox = try Sandbox()
        let recording = try await Self.movie(at: sandbox.url("Screen Recording.mov"), author: "ReplayKitRecording")
        #expect(ScreenCaptureMarker.isMovie(recording))
        #expect(await ScreenCaptureMarker.isPresent(inMovieAt: recording))
        #expect(await ScreenCaptureMarker.isPresent(at: recording))
    }

    @Test func anyOtherMovieIsNotARecording() async throws {
        let sandbox = try Sandbox()
        let camera = try await Self.movie(at: sandbox.url("IMG_0001.mov"), author: nil)
        let edited = try await Self.movie(at: sandbox.url("cut.mov"), author: "Final Cut Pro")
        #expect(await !ScreenCaptureMarker.isPresent(at: camera))
        #expect(await !ScreenCaptureMarker.isPresent(at: edited))
        // Not a movie inside, whatever the name says.
        #expect(await !ScreenCaptureMarker.isPresent(at: try sandbox.file("fake.mov", bytes: 64)))
    }

    @Test func tellsMoviesFromImagesByExtension() {
        #expect(ScreenCaptureMarker.isMovie(URL(filePath: "/a/Screen Recording.mov")))
        #expect(ScreenCaptureMarker.isMovie(URL(filePath: "/a/clip.MP4")))
        #expect(!ScreenCaptureMarker.isMovie(URL(filePath: "/a/Screenshot.png")))
    }

    // MARK: Fixtures

    /// A 4×4 image, with `comment` as its EXIF user comment when given.
    private static func image(at url: URL, type: UTType, comment: String?) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = comment.map { [kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: $0]] } ?? [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    /// A one-frame 64×64 movie, with `author` as its QuickTime author when given.
    private static func movie(at url: URL, author: String?) async throws -> URL {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        if let author {
            let item = AVMutableMetadataItem()
            item.identifier = .quickTimeMetadataAuthor
            item.value = author as NSString
            item.dataType = kCMMetadataBaseDataType_UTF8 as String
            writer.metadata = [item]
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
        let frame = try #require(buffer)
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        #expect(adaptor.append(frame, withPresentationTime: .zero))
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
}
