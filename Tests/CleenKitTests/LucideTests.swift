import Foundation
import Testing
@testable import CleenKit

struct LucideSearchTests {
    private let index = LucideIndex(icons: [
        LucideIcon(name: "arrow-right", codepoint: 0xE049, tags: ["forward", "next", "direction", "east"]),
        LucideIcon(name: "arrow-right-left", codepoint: 0xE04A, tags: ["switch", "swap"]),
        LucideIcon(name: "camera", codepoint: 0xE060, tags: ["photo", "webcam", "video"]),
        LucideIcon(name: "check", codepoint: 0xE06C, tags: ["done", "todo", "tick", "complete"]),
        LucideIcon(name: "check-check", codepoint: 0xE06D, tags: ["done", "read"]),
        LucideIcon(name: "circle-alert", codepoint: 0xE077, tags: ["warning", "error"], aliases: ["alert-circle"]),
        LucideIcon(name: "circle-arrow-right", codepoint: 0xE078, tags: ["forward", "next"]),
        LucideIcon(name: "circle-check", codepoint: 0xE079, tags: ["done", "success"]),
        LucideIcon(name: "house", codepoint: 0xE0F5, tags: ["home", "living", "building"]),
    ])

    private func names(_ query: String, limit: Int = .max) -> [String] {
        index.search(query, limit: limit).map(\.name)
    }

    @Test func exactThenPrefixThenPartThenContains() {
        #expect(names("check") == ["check", "check-check", "circle-check"])
        #expect(names("arrow-right") == ["arrow-right", "arrow-right-left", "circle-arrow-right"])
    }

    @Test func namesBeatTags() {
        // "done" is only a tag: shorter names first among equals.
        #expect(names("done") == ["check", "check-check", "circle-check"])
        // "home" is house's tag; nothing is named after it.
        #expect(names("home") == ["house"])
    }

    @Test func spacesAndCaseMeanTheSlug() {
        #expect(names("Arrow Right").first == "arrow-right")
        #expect(names("arrow_right").first == "arrow-right")
        #expect(names("ArrowRight").first == "arrow-right")
    }

    @Test func wordsInAnyOrderMatchNameParts() {
        #expect(names("check circle") == ["circle-check"])
    }

    @Test func oldNamesStillFind() {
        #expect(names("alert-circle") == ["circle-alert"])
        #expect(names("alert") == ["circle-alert"])
    }

    @Test func foldsAccentsAndCase() {
        #expect(names("CÂMERA") == ["camera"])
    }

    @Test func insideATagOnlyFromThreeLetters() {
        #expect(names("cam") == ["camera"])
        #expect(names("bcam") == ["camera"])
        #expect(names("bc").isEmpty)
    }

    @Test func emptyQueryAndLimit() {
        #expect(names("   ").isEmpty)
        #expect(names("check", limit: 1) == ["check"])
        #expect(names("zzz").isEmpty)
    }

    @Test func lookUpByName() {
        #expect(index.icon(named: "house")?.codepoint == 0xE0F5)
        #expect(index.icon(named: "nope") == nil)
    }
}

struct LucideIconTests {
    @Test func componentNames() {
        #expect(LucideName.pascalCase("arrow-right") == "ArrowRight")
        #expect(LucideName.pascalCase("a-arrow-down") == "AArrowDown")
        #expect(LucideName.pascalCase("arrow-down-0-1") == "ArrowDown01")
        #expect(LucideName.pascalCase("grid-2x2") == "Grid2x2")
        #expect(LucideName.pascalCase("x") == "X")
    }

    @Test func snippets() {
        let icon = LucideIcon(name: "arrow-right", codepoint: 0xE049)
        #expect(icon.jsx == "<ArrowRight />")
        #expect(icon.htmlTag == "<i data-lucide=\"arrow-right\"></i>")
        #expect(icon.pageURL.absoluteString == "https://lucide.dev/icons/arrow-right")
        #expect(icon.glyph.unicodeScalars.first?.value == 0xE049)
    }

    @Test func recentsMoveToTheFrontAndCap() {
        #expect(LucideRecents.record("b", in: ["a", "b", "c"]) == ["b", "a", "c"])
        #expect(LucideRecents.record("d", in: ["a", "b", "c"], limit: 3) == ["d", "a", "b"])
    }
}

struct LucideCatalogTests {
    private let info = Data(#"""
    {
      "arrow-right": { "encodedCode": "\\e049", "prefix": "icon", "className": "icon-arrow-right", "unicode": "&#57417;" },
      "circle-alert": { "encodedCode": "\\e077", "unicode": "&#57463;" },
      "alert-circle": { "encodedCode": "\\e077", "unicode": "&#57463;" },
      "trash-2": { "unicode": "&#57685;" },
      "broken": { "encodedCode": "nope" }
    }
    """#.utf8)
    private let tags = Data(#"{ "arrow-right": ["next", "forward"], "circle-alert": ["warning"] }"#.utf8)

    @Test func readsIconsAToZWithAliases() throws {
        let icons = try #require(LucideCatalog.parse(info: info, tags: tags))
        #expect(icons.map(\.name) == ["arrow-right", "circle-alert", "trash-2"])
        #expect(icons[0].codepoint == 0xE049)
        #expect(icons[0].tags == ["next", "forward"])
        #expect(icons[1].aliases == ["alert-circle"])
        // An untagged icon with a glyph of its own is still an icon, from `unicode`.
        #expect(icons[2].codepoint == 57685)
        #expect(icons[2].tags.isEmpty)
    }

    @Test func badTagsOnlyCostTheTags() throws {
        let icons = try #require(LucideCatalog.parse(info: info, tags: Data("[".utf8)))
        #expect(icons.count == 3)
        #expect(LucideCatalog.parse(info: Data("[]".utf8), tags: tags) == nil)
    }

    @Test func codepoints() {
        #expect(LucideCatalog.codepoint(encoded: "\\e585", unicode: nil) == 0xE585)
        #expect(LucideCatalog.codepoint(encoded: nil, unicode: "&#58757;") == 0xE585)
        #expect(LucideCatalog.codepoint(encoded: nil, unicode: "&#xe585;") == 0xE585)
        #expect(LucideCatalog.codepoint(encoded: "\\d800", unicode: nil) == nil)
    }

    @Test func cleansTheSVG() {
        let file = """
        <!-- @license lucide-static v1.61.0 - ISC -->
        <svg
          class="lucide lucide-arrow-right"
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M5 12h14" />
          <path d="m12 5 7 7-7 7" />
        </svg>

        """
        let svg = LucideSVG.clean(file)
        #expect(svg == #"<svg class="lucide lucide-arrow-right" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14" /><path d="m12 5 7 7-7 7" /></svg>"#)
        #expect(LucideSVG.looksLikeSVG(svg))
        #expect(!LucideSVG.looksLikeSVG("Not found: /icons/nope.svg"))
    }
}

struct LucideSourceTests {
    @Test func versionFromTheRedirect() {
        #expect(LucideSource.version(fromLocation: "/lucide-static@1.61.0/package.json") == "1.61.0")
        #expect(LucideSource.version(fromLocation: "https://unpkg.com/lucide-static@0.475.0-rc.1/font/info.json") == "0.475.0-rc.1")
        #expect(LucideSource.version(fromLocation: "/lucide-static@latest/package.json") == nil)
        #expect(LucideSource.version(fromLocation: "/react@18.3.1/index.js") == nil)
    }

    @Test func comparesVersionsByNumber() {
        #expect(LucideSource.isNewer("1.10.0", than: "1.9.3"))
        #expect(LucideSource.isNewer("2.0", than: "1.99.99"))
        #expect(!LucideSource.isNewer("1.61.0", than: "1.61.0"))
        #expect(!LucideSource.isNewer("1.60.9", than: "1.61.0"))
    }

    @Test func checksWeekly() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        #expect(LucideSource.needsCheck(lastChecked: nil, now: now))
        #expect(!LucideSource.needsCheck(lastChecked: now.addingTimeInterval(-6 * 86_400), now: now))
        #expect(LucideSource.needsCheck(lastChecked: now.addingTimeInterval(-7 * 86_400), now: now))
        #expect(LucideSource.needsCheck(lastChecked: now.addingTimeInterval(3_600), now: now))
    }

    @Test func pinnedURLs() {
        #expect(LucideSource.svgURL(version: "1.61.0", name: "arrow-right").absoluteString == "https://unpkg.com/lucide-static@1.61.0/icons/arrow-right.svg")
    }
}
