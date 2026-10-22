import Foundation

/// Something an app left in `~/Library` (or a system launch folder).
public struct Leftover: Sendable, Identifiable, Hashable {
    public enum Place: String, Sendable, CaseIterable {
        case applicationSupport = "Dados do app"
        case caches = "Cache"
        case preferences = "Preferências"
        case containers = "Container"
        case groupContainers = "Container compartilhado"
        case savedState = "Estado das janelas"
        case logs = "Logs"
        case webData = "Dados da web"
        case cookies = "Cookies"
        case scripts = "Scripts"
        case launchAgents = "Item de inicialização"
        case systemLaunch = "Serviço do sistema"
        case helpers = "Ajudante privilegiado"

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
