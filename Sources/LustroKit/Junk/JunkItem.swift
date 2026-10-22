import Foundation

public struct JunkItem: Sendable, Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let size: Int64
    public let categoryID: String
    public let removal: RemovalMode
    public let selectedByDefault: Bool
    /// Why the item starts unselected, shown next to it.
    public let note: String?

    public var request: RemovalRequest { RemovalRequest(url: url, size: size, mode: removal) }
}
