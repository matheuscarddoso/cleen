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

extension SpaceNode {
    /// A copy of this tree without the node `id`, with every ancestor's size reduced to
    /// match. Used after something is moved to the Trash so the map stays truthful
    /// without a rescan.
    public func removing(_ id: String) -> SpaceNode {
        guard let index = children.firstIndex(where: { $0.id == id }) else {
            guard let path = children.firstIndex(where: { id.hasPrefix($0.id + "/") }) else { return self }
            var updated = children
            let before = updated[path].size
            updated[path] = updated[path].removing(id)
            let delta = before - updated[path].size
            return SpaceNode(
                id: self.id, name: name, size: size - delta, isDirectory: isDirectory, isAggregate: isAggregate,
                children: updated.sorted { $0.isAggregate == $1.isAggregate ? $0.size > $1.size : !$0.isAggregate }
            )
        }
        var updated = children
        let removed = updated.remove(at: index)
        return SpaceNode(
            id: self.id, name: name, size: size - removed.size, isDirectory: isDirectory,
            isAggregate: isAggregate, children: updated
        )
    }
}
