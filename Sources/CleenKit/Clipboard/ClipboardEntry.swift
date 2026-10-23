import Foundation

/// One thing that was copied, as the history keeps it.
public struct ClipboardEntry: Codable, Sendable, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case text
        case link
        case image
        case files
    }

    public let id: UUID
    public let kind: Kind
    /// Text and links; for files, the joined paths (so search finds them).
    public let text: String?
    /// Image file name inside the history folder.
    public let imageFile: String?
    public let imageWidth: Int?
    public let imageHeight: Int?
    public let files: [String]?
    public let byteCount: Int
    /// Identifies the same content copied again.
    public let contentHash: String
    public var sourceBundleID: String?
    public var sourceName: String?
    public let firstCopied: Date
    public var lastCopied: Date
    public var timesCopied: Int
    /// Pinned copies stay first and never fall off the end. Optional so older saved
    /// histories still decode.
    public var isPinned: Bool?

    public var pinned: Bool { isPinned ?? false }

    public init(
        kind: Kind,
        text: String? = nil,
        imageFile: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        files: [String]? = nil,
        byteCount: Int,
        contentHash: String,
        sourceBundleID: String?,
        sourceName: String?,
        copiedAt: Date = .now
    ) {
        id = UUID()
        self.kind = kind
        self.text = text
        self.imageFile = imageFile
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.files = files
        self.byteCount = byteCount
        self.contentHash = contentHash
        self.sourceBundleID = sourceBundleID
        self.sourceName = sourceName
        firstCopied = copiedAt
        lastCopied = copiedAt
        timesCopied = 1
    }

    /// The line shown in the list, like Raycast's: the text's first line, or
    /// "Imagem (2416×1057)", or the file name.
    public var title: String {
        switch kind {
        case .text, .link:
            let line = (text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return line.trimmingCharacters(in: .whitespaces).isEmpty ? "Texto vazio" : line.trimmingCharacters(in: .whitespaces)
        case .image:
            if let imageWidth, let imageHeight { return "Imagem (\(imageWidth)×\(imageHeight))" }
            return "Imagem"
        case .files:
            let names = (files ?? []).map { URL(filePath: $0).lastPathComponent }
            return names.count > 1 ? "\(names[0]) e mais \(names.count - 1)" : (names.first ?? "Arquivo")
        }
    }

    public func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return title.localizedStandardContains(query)
            || (text?.localizedStandardContains(query) ?? false)
            || (sourceName?.localizedStandardContains(query) ?? false)
    }
}
