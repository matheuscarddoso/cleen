/// The tools in the notch's tab bar.
enum NotchTab: String, CaseIterable, Identifiable {
    case home
    case calendar
    case shelf
    case ai
    case overview
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
        case .calendar: "Calendário"
        case .shelf: "Shelf"
        case .ai: "Uso de IA"
        case .overview: "Visão geral"
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
        case .calendar: "calendar"
        case .shelf: "tray.and.arrow.down.fill"
        case .ai: "chart.bar.xaxis"
        case .overview: "internaldrive.fill"
        case .clean: "trash"
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
        case .home, .overview, .calendar, .shelf, .ai: .overview
        case .clean: .junk
        case .projects: .projects
        case .files: .largeFiles
        case .system: .monitor
        case .startup: .startup
        case .maintenance: .maintenance
        }
    }
}
