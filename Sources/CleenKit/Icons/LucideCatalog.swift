import Foundation

/// Reads lucide-static's `font/info.json` (name → code point) and `tags.json`
/// (name → search tags) into the list of icons, A to Z.
public enum LucideCatalog {
    /// `nil` when `info.json` isn't the map it should be; a broken `tags.json` only costs
    /// the tags.
    public static func parse(info: Data, tags: Data) -> [LucideIcon]? {
        guard let raw = try? JSONDecoder().decode([String: RawGlyph].self, from: info) else { return nil }
        let tagsByName = (try? JSONDecoder().decode([String: [String]].self, from: tags)) ?? [:]

        var namesByCode: [UInt32: [String]] = [:]
        for (name, glyph) in raw {
            guard let code = glyph.codepoint else { continue }
            namesByCode[code, default: []].append(name)
        }

        var icons: [LucideIcon] = []
        icons.reserveCapacity(namesByCode.count)
        for (code, names) in namesByCode {
            // info.json also lists the deprecated names, which share the code point of the
            // icon that replaced them and have no tags. The tagged names are the icons;
            // the rest become their aliases. A glyph no one tagged keeps its first name.
            let sorted = names.sorted()
            let tagged = sorted.filter { tagsByName[$0] != nil }
            let canonical = tagged.isEmpty ? [sorted[0]] : tagged
            let aliases = sorted.filter { !canonical.contains($0) }
            for name in canonical {
                icons.append(LucideIcon(name: name, codepoint: code, tags: tagsByName[name] ?? [], aliases: aliases))
            }
        }
        icons.sort { $0.name < $1.name }
        return icons
    }

    /// `"\\e585"` (the CSS escape, `encodedCode`) or `"&#58757;"` (`unicode`).
    static func codepoint(encoded: String?, unicode: String?) -> UInt32? {
        if let encoded {
            let hex = encoded.drop { $0 == "\\" }
            if let value = UInt32(hex, radix: 16), Unicode.Scalar(value) != nil { return value }
        }
        if let unicode, unicode.hasPrefix("&#"), unicode.hasSuffix(";") {
            let body = unicode.dropFirst(2).dropLast()
            let value = body.first == "x" ? UInt32(body.dropFirst(), radix: 16) : UInt32(body)
            if let value, Unicode.Scalar(value) != nil { return value }
        }
        return nil
    }

    private struct RawGlyph: Decodable {
        var encodedCode: String?
        var unicode: String?

        var codepoint: UInt32? { LucideCatalog.codepoint(encoded: encodedCode, unicode: unicode) }
    }
}

/// Tidies an icon's SVG file for pasting: no license comment, one line, nothing else
/// changed (same attributes, same paths).
public enum LucideSVG {
    public static func clean(_ svg: String) -> String {
        var text = svg
        while let start = text.range(of: "<!--"), let end = text.range(of: "-->", range: start.upperBound..<text.endIndex) {
            text.removeSubrange(start.lowerBound..<end.upperBound)
        }
        let joined = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return joined
            .replacing(" >", with: ">")
            .replacing("> <", with: "><")
    }

    /// Whether a download really is an SVG and not an error page.
    public static func looksLikeSVG(_ text: String) -> Bool {
        text.contains("<svg") && text.contains("</svg>")
    }
}
