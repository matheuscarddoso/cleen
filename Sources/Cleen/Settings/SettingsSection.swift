/// The pages of Ajustes, grouped like OmniNotch's settings sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case displays
    case notch
    case tabs
    case cleaning
    case aiUsage
    case agents
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "Geral")
        case .displays: String(localized: "Telas")
        case .notch: String(localized: "Aparência")
        case .tabs: String(localized: "Abas")
        case .cleaning: String(localized: "Limpeza")
        case .aiUsage: String(localized: "Uso de IA")
        case .agents: String(localized: "Claude Code")
        case .about: String(localized: "Sobre")
        }
    }

    var subtitle: String {
        switch self {
        case .general: String(localized: "Como o Cleen começa, onde aparece e quando avisa.")
        case .displays: String(localized: "O brilho de cada tela, inclusive a do monitor externo.")
        case .notch: String(localized: "Como o notch abre e o que mostra fechado.")
        case .tabs: String(localized: "As ferramentas na barra do notch e a ordem delas.")
        case .cleaning: String(localized: "O que conta como projeto parado e arquivo grande.")
        case .aiUsage: String(localized: "As ferramentas de IA que aparecem no Uso de IA e no Início.")
        case .agents: String(localized: "Os pedidos de permissão, respondidos no notch.")
        case .about: String(localized: "Permissões e o que o Cleen já fez.")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .displays: "sun.max"
        case .notch: "rectangle.topthird.inset.filled"
        case .tabs: "square.grid.2x2"
        case .cleaning: "trash"
        case .aiUsage: "chart.bar.xaxis"
        case .agents: ClaudeLogo.symbolName
        case .about: "info.circle"
        }
    }

    /// Sidebar headings, as in OmniNotch: "NOTCH", "FERRAMENTAS".
    static let groups: [(title: String?, sections: [SettingsSection])] = [
        (nil, [.general, .displays]),
        (String(localized: "Notch"), [.notch, .tabs]),
        (String(localized: "Ferramentas"), [.cleaning, .aiUsage, .agents]),
        ("Cleen", [.about]),
    ]
}
