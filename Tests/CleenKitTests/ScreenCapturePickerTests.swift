import CoreGraphics
import Foundation
import Testing
@testable import CleenKit

@Suite struct ScreenCapturePickerTests {
    // This Mac: a 1470×956 built-in display, a 1920×1080 one above it and 229 pt to the left.
    private let mainHeight = 956.0
    private let builtIn = CGRect(x: 0, y: 0, width: 1470, height: 956)
    private let external = CGRect(x: -229, y: 956, width: 1920, height: 1080)

    @Test func readsTheAttributeAsWrittenByTheScreenshotService() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: [-229.0, -1080.0, 1920.0, 1080.0], format: .binary, options: 0)
        #expect(ScreenCapturePicker.globalRect(fromAttribute: data) == CGRect(x: -229, y: -1080, width: 1920, height: 1080))
    }

    @Test func rejectsAnythingElse() throws {
        let wrong = try PropertyListSerialization.data(fromPropertyList: [1.0, 2.0], format: .binary, options: 0)
        #expect(ScreenCapturePicker.globalRect(fromAttribute: wrong) == nil)
        #expect(ScreenCapturePicker.globalRect(fromAttribute: Data("nope".utf8)) == nil)
        let empty = try PropertyListSerialization.data(fromPropertyList: [0.0, 0.0, 0.0, 0.0], format: .binary, options: 0)
        #expect(ScreenCapturePicker.globalRect(fromAttribute: empty) == nil)
    }

    @Test func convertsScreenFramesToGlobalDisplayCoordinates() {
        #expect(ScreenCapturePicker.globalRect(ofScreenFrame: builtIn, mainScreenHeight: mainHeight) == CGRect(x: 0, y: 0, width: 1470, height: 956))
        #expect(ScreenCapturePicker.globalRect(ofScreenFrame: external, mainScreenHeight: mainHeight) == CGRect(x: -229, y: -1080, width: 1920, height: 1080))
    }

    @Test func picksTheCaptureOfTheDisplayTheNotchOpensOn() {
        // ⌘⇧3 with both displays: the built-in's file, then the external's "(2)".
        let rects: [CGRect?] = [CGRect(x: 0, y: 0, width: 1470, height: 956), CGRect(x: -229, y: -1080, width: 1920, height: 1080)]
        let onExternal = ScreenCapturePicker.globalRect(ofScreenFrame: external, mainScreenHeight: mainHeight)
        let onBuiltIn = ScreenCapturePicker.globalRect(ofScreenFrame: builtIn, mainScreenHeight: mainHeight)
        #expect(ScreenCapturePicker.index(for: onExternal, among: rects) == 1)
        #expect(ScreenCapturePicker.index(for: onBuiltIn, among: rects) == 0)
    }

    @Test func aSelectionOnAnotherDisplayDoesNotMatch() {
        let selection: [CGRect?] = [CGRect(x: 100, y: -600, width: 300, height: 200)]
        let onBuiltIn = ScreenCapturePicker.globalRect(ofScreenFrame: builtIn, mainScreenHeight: mainHeight)
        #expect(ScreenCapturePicker.index(for: onBuiltIn, among: selection) == nil)
        #expect(ScreenCapturePicker.index(for: onBuiltIn, among: [nil]) == nil)
    }
}
