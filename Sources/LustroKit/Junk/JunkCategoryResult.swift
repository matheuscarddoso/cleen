import Foundation

public struct JunkCategoryResult: Sendable, Identifiable, Hashable {
    public var id: String { category.id }
    public let category: JunkCategory
    /// Largest first.
    public let items: [JunkItem]

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}
