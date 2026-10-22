import CleenKit

/// One line of the junk list: a file category or a tool that frees space itself.
enum JunkRow: Identifiable {
    case category(JunkCategoryResult)
    case tool(ToolCleanup)

    var id: String {
        switch self {
        case .category(let result): result.id
        case .tool(let tool): "tool-\(tool.kind.rawValue)"
        }
    }

    var size: Int64 {
        switch self {
        case .category(let result): result.totalSize
        case .tool(let tool): tool.reclaimable
        }
    }
}
