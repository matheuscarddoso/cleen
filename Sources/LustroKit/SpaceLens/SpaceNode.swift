import Foundation

/// One folder or file in the disk map. Small entries are folded into a single
/// aggregate node per folder so a whole-disk tree stays a few megabytes in memory.
public struct SpaceNode: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let size: Int64
    public let isDirectory: Bool
    /// Stands for many small entries; not navigable and not removable.
    public let isAggregate: Bool
    /// Largest first.
    public let children: [SpaceNode]

    public var url: URL { URL(filePath: id) }

    public var isNavigable: Bool { isDirectory && !isAggregate && !children.isEmpty }
}
