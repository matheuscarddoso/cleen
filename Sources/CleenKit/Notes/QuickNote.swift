import Foundation

/// One quick note: plain text, no title field. The first line with words in it names it.
public struct QuickNote: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var updatedAt: Date

    public init(id: UUID = UUID(), text: String = "", updatedAt: Date = .now) {
        self.id = id
        self.text = text
        self.updatedAt = updatedAt
    }

    /// Nothing but spaces and line breaks.
    public var isBlank: Bool { text.allSatisfy(\.isWhitespace) }

    /// The first line that has words in it, trimmed: "Lista do mercado".
    public var title: String? {
        lines.first
    }

    /// The note without its blank lines, so a glance of a few lines shows words.
    public var preview: String {
        lines.joined(separator: "\n")
    }

    private var lines: [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
