import AppKit
import CleenKit

nonisolated extension NSAttributedString.Key {
    /// Characters laid out as nothing: a list item's indent and marker, drawn instead.
    static let markdownHidden = NSAttributedString.Key("app.cleen.markdownHidden")
    /// What to draw where the hidden marker was.
    static let markdownDecoration = NSAttributedString.Key("app.cleen.markdownDecoration")
}

/// What the layout manager draws in a list item's hanging indent.
nonisolated enum MarkdownDecoration: Equatable {
    case bullet(level: Int)
    case checkbox(level: Int, checked: Bool)
    case quote
}

/// Styles a note's Markdown in place, the way Bear and Apple Notes show it: headings
/// larger, **bold**, *italic*, `code` and ~~struck~~ text formatted with their markers
/// dimmed, list markers swapped for a dot or a checkbox, ticked items struck and greyed.
/// The text itself never changes: what's saved is plain Markdown.
nonisolated struct MarkdownStyler {
    let baseSize: CGFloat

    /// Width of one nesting level, and of the room a dot or checkbox takes.
    var levelWidth: CGFloat { baseSize * 1.25 }
    var markerWidth: CGFloat { baseSize * 1.45 }

    var baseFont: NSFont { .systemFont(ofSize: baseSize) }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: NSColor.white, .paragraphStyle: paragraph(indent: 0)]
    }

    func paragraph(indent: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = baseSize * 0.16
        style.paragraphSpacing = baseSize * 0.1
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        return style
    }

    func style(_ storage: NSTextStorage) {
        let text = storage.string as NSString
        let whole = NSRange(location: 0, length: text.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: whole)
        text.enumerateSubstrings(in: whole, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            styleLine(storage, text: text, range: range)
        }
        storage.endEditing()
    }

    private func styleLine(_ storage: NSTextStorage, text: NSString, range: NSRange) {
        let line = MarkdownLine(text.substring(with: range))
        let prefix = NSRange(location: range.location, length: min(line.prefixLength, range.length))
        let dim = NSColor.white.withAlphaComponent(0.32)
        switch line.kind {
        case .plain:
            break
        case .heading(let level):
            let size = baseSize * [1.45, 1.25, 1.1][max(0, min(level - 1, 2))]
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .semibold), range: range)
            storage.addAttribute(.foregroundColor, value: dim, range: prefix)
        case .bullet, .checklist:
            let indent = CGFloat(line.level) * levelWidth + markerWidth
            storage.addAttribute(.paragraphStyle, value: paragraph(indent: indent), range: range)
            storage.addAttribute(.markdownHidden, value: true, range: prefix)
            let decoration: MarkdownDecoration
            if case .checklist(let checked) = line.kind {
                decoration = .checkbox(level: line.level, checked: checked)
                if checked {
                    let words = NSRange(location: prefix.upperBound, length: range.upperBound - prefix.upperBound)
                    storage.addAttributes([.foregroundColor: NSColor.white.withAlphaComponent(0.42), .strikethroughStyle: NSUnderlineStyle.single.rawValue], range: words)
                }
            } else {
                decoration = .bullet(level: line.level)
            }
            storage.addAttribute(.markdownDecoration, value: decoration.encoded, range: prefix)
        case .numbered:
            let indent = CGFloat(line.level) * levelWidth
            storage.addAttribute(.paragraphStyle, value: paragraph(indent: indent), range: range)
            storage.addAttribute(.markdownHidden, value: true, range: NSRange(location: range.location, length: min(line.indent, range.length)))
            let marker = NSRange(location: range.location + line.indent, length: min(line.markerLength, range.length - line.indent))
            storage.addAttributes([.foregroundColor: NSColor.white.withAlphaComponent(0.55), .font: NSFont.monospacedDigitSystemFont(ofSize: baseSize, weight: .medium)], range: marker)
        case .quote:
            storage.addAttribute(.paragraphStyle, value: paragraph(indent: markerWidth * 0.8), range: range)
            storage.addAttribute(.markdownHidden, value: true, range: prefix)
            storage.addAttribute(.markdownDecoration, value: MarkdownDecoration.quote.encoded, range: prefix)
            storage.addAttribute(.foregroundColor, value: NSColor.white.withAlphaComponent(0.6), range: range)
        }
        styleInline(storage, text: text, range: NSRange(location: prefix.upperBound, length: range.upperBound - prefix.upperBound))
    }

    /// **bold**, *italic* / _italic_, `code`, ~~struck~~, each with its markers dimmed.
    private func styleInline(_ storage: NSTextStorage, text: NSString, range: NSRange) {
        guard range.length > 1 else { return }
        let dim = NSColor.white.withAlphaComponent(0.3)
        for (pattern, apply) in inlineRules {
            pattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
                guard let match, match.numberOfRanges == 3 else { return }
                let whole = match.range
                let inner = match.range(at: 2)
                apply(storage, inner)
                storage.addAttribute(.foregroundColor, value: dim, range: NSRange(location: whole.location, length: inner.location - whole.location))
                storage.addAttribute(.foregroundColor, value: dim, range: NSRange(location: inner.upperBound, length: whole.upperBound - inner.upperBound))
            }
        }
    }

    private var inlineRules: [(NSRegularExpression, (NSTextStorage, NSRange) -> Void)] {
        let size = baseSize
        return [
            (Self.code, { storage, range in
                storage.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: size * 0.92, weight: .regular),
                    .backgroundColor: NSColor.white.withAlphaComponent(0.09),
                ], range: range)
            }),
            (Self.bold, { storage, range in
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .semibold), range: range)
            }),
            (Self.italic, { storage, range in
                let font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: size), toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: font, range: range)
            }),
            (Self.strike, { storage, range in
                storage.addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: NSColor.white.withAlphaComponent(0.5)], range: range)
            }),
        ]
    }

    // Each pattern: group 1 the opening marker, group 2 the words.
    private static let code = try! NSRegularExpression(pattern: "(`)([^`\\n]+)`")
    private static let bold = try! NSRegularExpression(pattern: "(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
    private static let italic = try! NSRegularExpression(pattern: "(?<![*_\\w])([*_])(?=\\S)([^*_\\n]+?)(?<=\\S)\\1(?![*_\\w])")
    private static let strike = try! NSRegularExpression(pattern: "(~~)(?=\\S)(.+?)(?<=\\S)~~")
}

nonisolated extension MarkdownDecoration {
    /// Stored in the text as a string, so attributes compare cheaply.
    var encoded: String {
        switch self {
        case .bullet(let level): "bullet:\(level)"
        case .checkbox(let level, let checked): "check:\(level):\(checked ? 1 : 0)"
        case .quote: "quote"
        }
    }

    init?(encoded: String) {
        let parts = encoded.split(separator: ":")
        switch parts.first {
        case "bullet": self = .bullet(level: parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
        case "check": self = .checkbox(level: parts.count > 1 ? Int(parts[1]) ?? 0 : 0, checked: parts.count > 2 && parts[2] == "1")
        case "quote": self = .quote
        default: return nil
        }
    }
}
