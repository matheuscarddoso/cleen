import Foundation

public struct JunkCategory: Sendable, Identifiable, Hashable {
    public enum Group: Sendable, CaseIterable {
        case system
        case developer
        case browsers
    }

    public let id: String
    public let title: String
    public let summary: String
    public let symbol: String
    public let group: Group
    public let sources: [JunkSource]
    public let removal: RemovalMode
    public let selectedByDefault: Bool
    /// Some locations (Mail, Safari, the Trash) are only visible with Full Disk Access.
    public let needsFullDiskAccess: Bool
    /// Children never offered from `.contents` sources, matched by exact file name.
    public let excludedNames: Set<String>

    public init(
        id: String,
        title: String,
        summary: String,
        symbol: String,
        group: Group,
        sources: [JunkSource],
        removal: RemovalMode = .delete,
        selectedByDefault: Bool = true,
        needsFullDiskAccess: Bool = false,
        excludedNames: Set<String> = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.symbol = symbol
        self.group = group
        self.sources = sources
        self.removal = removal
        self.selectedByDefault = selectedByDefault
        self.needsFullDiskAccess = needsFullDiskAccess
        self.excludedNames = excludedNames
    }
}
