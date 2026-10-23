/// What the menu bar shows next to the icon.
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case iconOnly
    case freeSpace
    case cpu
    case memory

    static let storageKey = "menuBarDisplay"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .iconOnly: String(localized: "Ícone")
        case .freeSpace: String(localized: "Disco")
        case .cpu: "CPU"
        case .memory: String(localized: "Memória")
        }
    }

    var title: String {
        switch self {
        case .iconOnly: String(localized: "Só o ícone")
        case .freeSpace: String(localized: "Espaço livre")
        case .cpu: String(localized: "Uso de CPU")
        case .memory: String(localized: "Uso de memória")
        }
    }
}
