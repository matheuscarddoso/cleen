import Foundation

/// Something an app left in `~/Library` (or a system launch folder).
public struct Leftover: Sendable, Identifiable, Hashable {
    public enum Place: Sendable, CaseIterable {
        case applicationSupport
        case caches
        case preferences
        case containers
        case groupContainers
        case savedState
        case logs
        case webData
        case cookies
        case scripts
        case launchAgents
        case systemLaunch
        case helpers

        /// What the folder is called in the interface.
        public var title: String {
            switch self {
            case .applicationSupport: String(localized: "Dados do app")
            case .caches: String(localized: "Cache")
            case .preferences: String(localized: "Preferências")
            case .containers: String(localized: "Container")
            case .groupContainers: String(localized: "Container compartilhado")
            case .savedState: String(localized: "Estado das janelas")
            case .logs: String(localized: "Logs")
            case .webData: String(localized: "Dados da web")
            case .cookies: String(localized: "Cookies")
            case .scripts: String(localized: "Scripts")
            case .launchAgents: String(localized: "Item de inicialização")
            case .systemLaunch: String(localized: "Serviço do sistema")
            case .helpers: String(localized: "Ajudante privilegiado")
            }
        }

        /// Places holding things the person made, as opposed to throwaway state.
        public var holdsUserData: Bool {
            switch self {
            case .applicationSupport, .containers, .groupContainers, .preferences: true
            default: false
            }
        }

        /// Root-owned locations that need an administrator to change.
        public var isSystemWide: Bool { self == .systemLaunch || self == .helpers }
    }

    public var id: URL { url }
    public let url: URL
    public let place: Place
    public let size: Int64

    public var request: RemovalRequest { RemovalRequest(url: url, size: size, mode: .trash) }
}
