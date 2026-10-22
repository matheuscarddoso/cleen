/// The pages of Ajustes, grouped like OmniNotch's settings sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case notch
    case tabs
    case cleaning
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Geral"
        case .notch: "Aparência"
        case .tabs: "Abas"
        case .cleaning: "Limpeza"
        case .about: "Sobre"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Como o Cleen começa, onde aparece e quando avisa."
        case .notch: "Como o notch abre e o que mostra fechado."
        case .tabs: "As ferramentas na barra do notch e a ordem delas."
        case .cleaning: "O que conta como projeto parado e arquivo grande."
        case .about: "Permissões e o que o Cleen já fez."
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .notch: "rectangle.topthird.inset.filled"
        case .tabs: "square.grid.2x2"
        case .cleaning: "trash"
        case .about: "info.circle"
        }
    }

    /// Sidebar headings, as in OmniNotch: "NOTCH", "FERRAMENTAS".
    static let groups: [(title: String?, sections: [SettingsSection])] = [
        (nil, [.general]),
        ("Notch", [.notch, .tabs]),
        ("Ferramentas", [.cleaning]),
        ("Cleen", [.about]),
    ]
}
