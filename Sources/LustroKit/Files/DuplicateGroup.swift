import Foundation

public struct DuplicateGroup: Sendable, Identifiable, Hashable {
    public let id: String
    /// Oldest first: the first copy is the one kept by default.
    public let files: [FoundFile]

    public var fileSize: Int64 { files.first?.size ?? 0 }
    /// What removing every copy but one frees.
    public var wasted: Int64 { fileSize * Int64(max(0, files.count - 1)) }
}
