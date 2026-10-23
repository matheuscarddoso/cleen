import Foundation

/// One Lucide icon (lucide.dev): its kebab-case name, where it sits in the icon font, and
/// what it's searched by.
public struct LucideIcon: Hashable, Identifiable, Sendable {
    /// "arrow-right": Lucide's canonical name, also the SVG's file name.
    public let name: String
    /// The icon font's private-use code point for this icon.
    public let codepoint: UInt32
    public let tags: [String]
    /// Older names Lucide still ships for the same glyph ("alert-circle" for
    /// "circle-alert"), so searching by the name you remember still finds it.
    public let aliases: [String]

    public init(name: String, codepoint: UInt32, tags: [String] = [], aliases: [String] = []) {
        self.name = name
        self.codepoint = codepoint
        self.tags = tags
        self.aliases = aliases
    }

    public var id: String { name }

    /// The icon as text in the Lucide font.
    public var character: Character {
        Character(Unicode.Scalar(codepoint) ?? "\u{FFFD}")
    }

    public var glyph: String { String(character) }

    // MARK: Ways to paste it

    /// lucide-react's component name: "arrow-right" → "ArrowRight", "grid-2x2" → "Grid2x2".
    public var componentName: String { LucideName.pascalCase(name) }

    /// `<ArrowRight />`
    public var jsx: String { "<\(componentName) />" }

    /// `<i data-lucide="arrow-right"></i>`: what `lucide.createIcons()` swaps for the SVG,
    /// the way Blade and plain HTML pages use Lucide.
    public var htmlTag: String { "<i data-lucide=\"\(name)\"></i>" }

    public var pageURL: URL {
        URL(string: "https://lucide.dev/icons/\(name)")!
    }
}

public enum LucideName {
    /// Mirrors lucide's own `toPascalCase`: every hyphen-separated part starts upper-case,
    /// the rest is kept as is ("arrow-down-0-1" → "ArrowDown01").
    public static func pascalCase(_ name: String) -> String {
        name.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }
}
