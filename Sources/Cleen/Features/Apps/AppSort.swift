enum AppSort: String, CaseIterable, Identifiable {
    case size
    case name
    case lastUsed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: String(localized: "Tamanho")
        case .name: String(localized: "Nome")
        case .lastUsed: String(localized: "Menos usados")
        }
    }
}
