/// The tools in the notch's tab bar.
enum NotchTab: String, CaseIterable, Identifiable {
    case home
    case clean
    case projects
    case files
    case system
    case startup
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Cleen"
        case .clean: "Limpeza"
        case .projects: "Projetos"
        case .files: "Arquivos grandes"
        case .system: "Sistema"
        case .startup: "Inicialização"
        case .maintenance: "Manutenção"
        }
    }

    var symbol: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .clean: "sparkles"
        case .projects: "chevron.left.forwardslash.chevron.right"
        case .files: "doc.fill"
        case .system: "chart.bar.fill"
        case .startup: "power"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }

    /// The full-window section with the same content, for "open in window".
    var route: Route {
        switch self {
        case .home: .overview
        case .clean: .junk
        case .projects: .projects
        case .files: .largeFiles
        case .system: .monitor
        case .startup: .startup
        case .maintenance: .maintenance
        }
    }
}
