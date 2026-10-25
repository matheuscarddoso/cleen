import CleenKit
import Foundation

/// The AI tools Uso de IA can show, each one switched on or off in Ajustes › Uso de IA.
enum AITool: String, CaseIterable, Identifiable {
    case claude
    case codex
    case cursor
    case copilot
    case grok

    var id: String { rawValue }

    init(_ provider: AIProvider) {
        switch provider {
        case .cursor: self = .cursor
        case .copilot: self = .copilot
        case .grok: self = .grok
        }
    }

    var name: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .cursor: AIProvider.cursor.name
        case .copilot: AIProvider.copilot.name
        case .grok: AIProvider.grok.name
        }
    }

    var symbol: String {
        switch self {
        case .claude: ClaudeLogo.symbolName
        case .codex: "terminal"
        case .cursor: AIProvider.cursor.symbol
        case .copilot: AIProvider.copilot.symbol
        case .grok: AIProvider.grok.symbol
        }
    }

    /// Every tool shows unless it was switched off.
    static func hiddenTools(in defaults: UserDefaults = .standard) -> Set<AITool> {
        Set(allCases.filter { defaults.object(forKey: $0.storageKey) as? Bool == false })
    }

    var storageKey: String { "aiUsage.shows.\(rawValue)" }
}
