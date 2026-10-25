import AppKit
import CleenKit

nonisolated extension NSAttributedString.Key {
    /// Characters laid out as nothing: a list item's indent and marker, drawn instead.
    static let markdownHidden = NSAttributedString.Key("app.cleen.markdownHidden")
    /// What to draw where the hidden marker was.
    static let markdownDecoration = NSAttributedString.Key("app.cleen.markdownDecoration")
}

/// What the layout manager draws where a rendered line's marker is hidden: `x` is where
/// the marker starts (after its indent), `width` how wide it is.
nonisolated enum MarkdownDecoration: Equatable {
    case bullet(x: CGFloat, width: CGFloat)
    case checkbox(x: CGFloat, checked: Bool)
    case quote(x: CGFloat)
}

/// Styles a note's Markdown in place, the way Obsidian's Live Preview shows it. The line
/// with the cursor shows its Markdown, markers dimmed, so it edits like plain text; every
/// other line is rendered: list markers become a dot or a checkbox, **bold**, *italic*,
/// `code` and ~~struck~~ lose their markers, headings their hashes, ticked items are
/// struck and greyed. The text itself never changes: what's saved is plain Markdown.
///
/// A rendered list item is indented by exactly its marker's width, so the words sit in
/// the same place whether the line shows its marker or its dot.
nonisolated struct MarkdownStyler {
    let baseSize: CGFloat

    var baseFont: NSFont { .systemFont(ofSize: baseSize) }
    private var markerFont: NSFont { .systemFont(ofSize: baseSize) }

    private var dim: NSColor { NSColor.white.withAlphaComponent(0.32) }

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

    /// How wide a marker is when shown: where the words start on a rendered line.
    func width(of marker: String) -> CGFloat {
        ceil((marker as NSString).size(withAttributes: [.font: markerFont]).width)
    }

    /// Restyles the lines `range` touches; the lines `active` touches show their Markdown.
    func style(_ storage: NSTextStorage, lines range: NSRange, active: NSRange) {
        let text = storage.string as NSString
        let lines = text.paragraphRange(for: NSRange(location: min(range.location, text.length), length: min(range.length, text.length - min(range.location, text.length))))
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: lines)
        text.enumerateSubstrings(in: lines, options: [.byParagraphs, .substringNotRequired]) { _, line, _, _ in
            let isActive = NSIntersectionRange(line, active).length > 0 || NSLocationInRange(active.location, NSRange(location: line.location, length: line.length + 1))
            styleLine(storage, text: text, range: line, active: isActive)
        }
        storage.endEditing()
    }

    private func styleLine(_ storage: NSTextStorage, text: NSString, range: NSRange, active: Bool) {
        let source = text.substring(with: range)
        let line = MarkdownLine(source)
        let prefix = NSRange(location: range.location, length: min(line.prefixLength, range.length))
        let marker = (source as NSString).substring(with: NSRange(location: 0, length: prefix.length))
        switch line.kind {
        case .plain:
            break
        case .heading(let level):
            let size = baseSize * [1.45, 1.25, 1.1][max(0, min(level - 1, 2))]
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .semibold), range: range)
            if active {
                storage.addAttribute(.foregroundColor, value: dim, range: prefix)
            } else {
                storage.addAttribute(.markdownHidden, value: true, range: prefix)
            }
        case .bullet, .checklist, .quote:
            // The marker keeps its own width either way: shown dimmed while editing,
            // hidden behind a dot, checkbox or bar otherwise.
            let indent = width(of: marker)
            if active {
                storage.addAttribute(.foregroundColor, value: dim, range: prefix)
                storage.addAttribute(.paragraphStyle, value: paragraph(indent: 0, hanging: indent), range: range)
            } else {
                storage.addAttribute(.paragraphStyle, value: paragraph(indent: indent), range: range)
                storage.addAttribute(.markdownHidden, value: true, range: prefix)
                let x = width(of: String(marker.prefix(line.indent)))
                let decoration: MarkdownDecoration = switch line.kind {
                case .checklist(let checked): .checkbox(x: x, checked: checked)
                case .quote: .quote(x: x)
                default: .bullet(x: x, width: width(of: "-"))
                }
                storage.addAttribute(.markdownDecoration, value: decoration.encoded, range: prefix)
            }
            if case .checklist(true) = line.kind {
                let words = NSRange(location: prefix.upperBound, length: range.upperBound - prefix.upperBound)
                storage.addAttributes([.foregroundColor: NSColor.white.withAlphaComponent(0.42), .strikethroughStyle: NSUnderlineStyle.single.rawValue], range: words)
            }
            if line.kind == .quote {
                storage.addAttribute(.foregroundColor, value: NSColor.white.withAlphaComponent(0.6), range: NSRange(location: prefix.upperBound, length: range.upperBound - prefix.upperBound))
            }
        case .numbered:
            storage.addAttribute(.paragraphStyle, value: paragraph(indent: 0, hanging: width(of: marker)), range: range)
            storage.addAttributes([.foregroundColor: NSColor.white.withAlphaComponent(0.55), .font: NSFont.monospacedDigitSystemFont(ofSize: baseSize, weight: .medium)], range: prefix)
        }
        styleInline(storage, text: text, range: NSRange(location: prefix.upperBound, length: range.upperBound - prefix.upperBound), active: active)
    }

    /// A list item's wrapped lines line up under its words, not under its marker.
    private func paragraph(indent: CGFloat, hanging: CGFloat) -> NSParagraphStyle {
        let style = paragraph(indent: indent).mutableCopy() as! NSMutableParagraphStyle
        style.headIndent = indent + hanging
        return style
    }

    /// **bold**, *italic* / _italic_, `code`, ~~struck~~: markers dimmed on the line being
    /// edited, hidden everywhere else.
    private func styleInline(_ storage: NSTextStorage, text: NSString, range: NSRange, active: Bool) {
        guard range.length > 1 else { return }
        for (pattern, apply) in inlineRules {
            pattern.enumerateMatches(in: text as String, range: range) { match, _, _ in
                guard let match, match.numberOfRanges == 3 else { return }
                let whole = match.range
                let inner = match.range(at: 2)
                apply(storage, inner)
                let markers = [
                    NSRange(location: whole.location, length: inner.location - whole.location),
                    NSRange(location: inner.upperBound, length: whole.upperBound - inner.upperBound),
                ]
                for marker in markers {
                    if active {
                        storage.addAttribute(.foregroundColor, value: dim, range: marker)
                    } else {
                        storage.addAttribute(.markdownHidden, value: true, range: marker)
                    }
                }
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
        case .bullet(let x, let width): "bullet:\(x):\(width)"
        case .checkbox(let x, let checked): "check:\(x):\(checked ? 1 : 0)"
        case .quote(let x): "quote:\(x)"
        }
    }

    init?(encoded: String) {
        let parts = encoded.split(separator: ":").map(String.init)
        guard parts.count >= 2, let x = Double(parts[1]) else { return nil }
        switch parts[0] {
        case "bullet": self = .bullet(x: x, width: parts.count > 2 ? Double(parts[2]) ?? 6 : 6)
        case "check": self = .checkbox(x: x, checked: parts.count > 2 && parts[2] == "1")
        case "quote": self = .quote(x: x)
        default: return nil
        }
    }
}
