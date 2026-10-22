import Foundation

/// Space held by a developer tool that must be released through the tool itself
/// (deleting Docker's disk image by hand would corrupt it).
public struct ToolCleanup: Sendable, Identifiable, Hashable {
    public enum Kind: String, Sendable {
        case docker
        case simulators
    }

    public var id: Kind { kind }
    public let kind: Kind
    public let title: String
    public let summary: String
    public let symbol: String
    public let reclaimable: Int64
    public let detail: String
    public let selectedByDefault: Bool
}
