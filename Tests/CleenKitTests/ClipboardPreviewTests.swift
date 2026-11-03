import CoreGraphics
import Foundation
import Testing
@testable import CleenKit

struct ClipboardPreviewTests {
    private func files(_ paths: [String]) -> ClipboardEntry {
        ClipboardEntry(kind: .files, text: paths.joined(separator: "\n"), files: paths, byteCount: 0, contentHash: UUID().uuidString, sourceBundleID: nil, sourceName: nil)
    }

    @Test func wordsHaveNoPicture() {
        let text = ClipboardEntry(kind: .text, text: "oi", byteCount: 2, contentHash: "a", sourceBundleID: nil, sourceName: nil)
        let link = ClipboardEntry(kind: .link, text: "https://cleen.app", byteCount: 17, contentHash: "b", sourceBundleID: nil, sourceName: nil)
        #expect(text.preview == nil)
        #expect(link.preview == nil)
    }

    @Test func pastedImageShowsTheSavedFile() {
        let image = ClipboardEntry(kind: .image, imageFile: "abc.png", imageWidth: 10, imageHeight: 10, byteCount: 1, contentHash: "c", sourceBundleID: nil, sourceName: nil)
        #expect(image.preview?.source == .storedImage(fileName: "abc.png"))
        #expect(image.preview?.anchor == .center)
        let lost = ClipboardEntry(kind: .image, byteCount: 1, contentHash: "d", sourceBundleID: nil, sourceName: nil)
        #expect(lost.preview == nil)
    }

    @Test(arguments: [
        "/Users/a/Desktop/Screenshot 2026-11-03 at 9.41.07 AM.png",
        "/Users/a/Pictures/IMG_0001.HEIC",
        "/Users/a/Pictures/photo.JPG",
        "/Users/a/Pictures/raw.dng",
    ])
    func copiedImageFilesAreDecodedDirectly(path: String) {
        #expect(files([path]).preview?.source == .imageFile(path: path))
    }

    @Test func otherFilesGoThroughQuickLook() {
        let pdf = "/Users/a/Documents/Contrato.pdf"
        #expect(files([pdf]).preview?.source == .quickLook(path: pdf))
        #expect(files([pdf]).preview?.anchor == .top)
        let movie = "/Users/a/Movies/clip.mov"
        #expect(files([movie]).preview?.anchor == .center)
        let folder = "/Users/a/Projects"
        #expect(files([folder]).preview?.source == .quickLook(path: folder))
    }

    @Test func severalFilesShowTheFirst() {
        let first = "/Users/a/one.png"
        #expect(files([first, "/Users/a/two.pdf"]).preview?.source == .imageFile(path: first))
        #expect(files([]).preview == nil)
    }

    @Test func pixelsRoundUpSoNothingIsDrawnSoft() {
        let pixels = ClipboardPreview.pixelSize(for: CGSize(width: 108, height: 52.3), scale: 2)
        #expect(pixels.width == 216)
        #expect(pixels.height == 105)
        let negative = ClipboardPreview.pixelSize(for: CGSize(width: -4, height: 10), scale: 0)
        #expect(negative.width == 0)
        #expect(negative.height == 10)
    }

    @Test func cacheKeyTellsEntriesAndSizesApart() {
        let id = UUID()
        let card = CGSize(width: 108, height: 69)
        #expect(ClipboardPreview.cacheKey(id: id, size: card, scale: 2) == ClipboardPreview.cacheKey(id: id, size: card, scale: 2))
        #expect(ClipboardPreview.cacheKey(id: id, size: card, scale: 2) != ClipboardPreview.cacheKey(id: id, size: card, scale: 1))
        #expect(ClipboardPreview.cacheKey(id: id, size: card, scale: 2) != ClipboardPreview.cacheKey(id: UUID(), size: card, scale: 2))
        #expect(ClipboardPreview.cacheKey(id: id, size: card, scale: 2) != ClipboardPreview.cacheKey(id: id, size: CGSize(width: 108, height: 40), scale: 2))
    }

    @Test func quickLookBoxCoversTallAndWidePictures() {
        let card = CGSize(width: 108, height: 52)
        let side = ClipboardPreview.quickLookSide(toFill: card)
        // A 1:2 page fitted into the square is still as wide as the card.
        #expect(side / 2 >= card.width)
        // A 2:1 frame fitted into the square is still as tall as the card.
        #expect(side / 2 >= card.height)
    }
}
