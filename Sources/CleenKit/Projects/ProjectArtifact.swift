import Foundation

public struct ProjectArtifact: Sendable, Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let kind: ArtifactKind
    public let size: Int64

    public var request: RemovalRequest { RemovalRequest(url: url, size: size, mode: .delete) }
}
