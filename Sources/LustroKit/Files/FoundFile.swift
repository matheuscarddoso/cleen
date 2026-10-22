import Foundation

public struct FoundFile: Sendable, Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public let modified: Date
    public let accessed: Date
    public let kind: FileKind

    public var name: String { url.lastPathComponent }

    /// The later of last change and last open: how long the file has really sat unused.
    public var lastUsed: Date { max(modified, accessed) }

    public var request: RemovalRequest { RemovalRequest(url: url, size: size, mode: .trash) }
}
