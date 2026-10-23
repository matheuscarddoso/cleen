import CoreGraphics
import Testing
@testable import CleenKit

struct ShelfSelectionTests {
    private let row = ["a", "b", "c", "d", "e"]

    @Test func plainClickPicksOnlyThatOne() {
        var selection = ShelfSelection<String>(["a", "c"])
        selection.click("d", mode: .replace, in: row)
        #expect(selection.ids == ["d"])
        #expect(selection.anchor == "d")
    }

    @Test func commandClickToggles() {
        var selection = ShelfSelection<String>()
        selection.click("b", mode: .replace, in: row)
        selection.click("d", mode: .toggle, in: row)
        #expect(selection.ids == ["b", "d"])
        selection.click("b", mode: .toggle, in: row)
        #expect(selection.ids == ["d"])
    }

    @Test func shiftClickTakesTheRangeFromTheAnchorEitherWay() {
        var selection = ShelfSelection<String>()
        selection.click("b", mode: .replace, in: row)
        selection.click("d", mode: .extend, in: row)
        #expect(selection.ordered(in: row) == ["b", "c", "d"])
        // The anchor stays, so a second ⇧-click re-ranges from it.
        selection.click("a", mode: .extend, in: row)
        #expect(selection.ordered(in: row) == ["a", "b"])
    }

    @Test func shiftClickWithoutAnAnchorActsLikeAClick() {
        var selection = ShelfSelection<String>()
        selection.click("c", mode: .extend, in: row)
        #expect(selection.ids == ["c"])
        #expect(selection.anchor == "c")
    }

    @Test func selectAllClearAndKeep() {
        var selection = ShelfSelection<String>()
        selection.selectAll(row)
        #expect(selection.count == 5)
        selection.keep(["a", "e"])
        #expect(selection.ids == ["a", "e"])
        selection.clear()
        #expect(selection.isEmpty && selection.anchor == nil)
    }

    @Test func keepDropsAnAnchorThatLeft() {
        var selection = ShelfSelection<String>()
        selection.click("b", mode: .replace, in: row)
        selection.keep(["a", "c"])
        #expect(selection.isEmpty)
        #expect(selection.anchor == nil)
    }

    @Test func arrowsStepAndStopAtTheEnds() {
        var selection = ShelfSelection<String>()
        selection.move(by: 1, in: row)
        #expect(selection.ids == ["a"])
        selection.move(by: -1, in: row)
        #expect(selection.ids == ["a"])
        selection.click("b", mode: .replace, in: row)
        selection.click("d", mode: .toggle, in: row)
        selection.move(by: 1, in: row)
        #expect(selection.ids == ["e"])
        selection.move(by: 1, in: row)
        #expect(selection.ids == ["e"])
        var fromNothing = ShelfSelection<String>()
        fromNothing.move(by: -1, in: row)
        #expect(fromNothing.ids == ["e"])
    }

    @Test func bandReplacesExtendsOrToggles() {
        var plain = ShelfSelection<String>(["a"])
        plain.beginBand(mode: .replace)
        #expect(plain.isEmpty)
        plain.updateBand(touching: ["b", "c"], mode: .replace)
        #expect(plain.ids == ["b", "c"])
        plain.updateBand(touching: ["b"], mode: .replace)
        #expect(plain.ids == ["b"])

        var extending = ShelfSelection<String>(["a"])
        extending.beginBand(mode: .extend)
        extending.updateBand(touching: ["a", "b"], mode: .extend)
        #expect(extending.ids == ["a", "b"])
        extending.updateBand(touching: [], mode: .extend)
        #expect(extending.ids == ["a"])

        var toggling = ShelfSelection<String>(["a", "b"])
        toggling.beginBand(mode: .toggle)
        toggling.updateBand(touching: ["b", "c"], mode: .toggle)
        #expect(toggling.ids == ["a", "c"])
    }

    @Test func bandTouchesFramesEvenWhenFlat() {
        let frames: [String: CGRect] = [
            "a": CGRect(x: 0, y: 0, width: 80, height: 90),
            "b": CGRect(x: 84, y: 0, width: 80, height: 90),
            "c": CGRect(x: 168, y: 0, width: 80, height: 90),
        ]
        let band = ShelfSelection<String>.band(from: CGPoint(x: 150, y: 40), to: CGPoint(x: 70, y: 40))
        #expect(band == CGRect(x: 70, y: 40, width: 80, height: 0))
        #expect(ShelfSelection.touched(by: band, frames: frames) == ["a", "b"])
        let outside = CGRect(x: 0, y: 100, width: 300, height: 10)
        #expect(ShelfSelection.touched(by: outside, frames: frames).isEmpty)
    }
}
