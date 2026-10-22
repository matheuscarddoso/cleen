/// What the menu bar shows next to the icon.
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case iconOnly
    case freeSpace
    case cpu
    case memory

    static let storageKey = "menuBarDisplay"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly: "Só o ícone"
        case .freeSpace: "Espaço livre"
        case .cpu: "Uso de CPU"
        case .memory: "Uso de memória"
        }
    }
}
