import Foundation

/// Turns a model's Markdown into what a single SwiftUI Text can show. Text renders the
/// inline part (bold, italics, code, links) but not blocks, so blocks become plain
/// equivalents first: bullets as "•", headings as bold lines, fenced code as inline code.
public enum ChatMarkdown {
    public static func prepare(_ markdown: String) -> String {
        var lines: [String] = []
        var inFence = false
        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence {
                // Inline code can't hold a backtick of its own; such a line stays as is.
                lines.append(trimmed.isEmpty || line.contains("`") ? line : "`\(line)`")
                continue
            }
            lines.append(block(line, trimmed: trimmed))
        }
        return lines.joined(separator: "\n")
    }

    private static func block(_ line: String, trimmed: String) -> String {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            return indent + "• " + trimmed.dropFirst(marker.count)
        }
        if trimmed.hasPrefix("#") {
            let hashes = trimmed.prefix { $0 == "#" }
            let title = trimmed.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
            if hashes.count <= 6, !title.isEmpty, trimmed.dropFirst(hashes.count).first == " " {
                return "**\(title)**"
            }
        }
        if trimmed == "---" || trimmed == "***" { return "" }
        return line
    }
}
