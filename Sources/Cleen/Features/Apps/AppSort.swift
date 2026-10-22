enum AppSort: String, CaseIterable, Identifiable {
    case size
    case name
    case lastUsed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: "Tamanho"
        case .name: "Nome"
        case .lastUsed: "Menos usados"
        }
    }
}
