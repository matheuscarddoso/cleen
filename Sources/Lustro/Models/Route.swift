/// Sections of the main window, in sidebar order.
enum Route: String, CaseIterable, Identifiable, Hashable {
    case overview
    case junk
    case projects
    case largeFiles
    case duplicates
    case spaceLens
    case uninstaller
    case leftovers
    case startup
    case monitor
    case maintenance
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Visão geral"
        case .junk: "Lixo do sistema"
        case .projects: "Projetos de código"
        case .largeFiles: "Arquivos grandes"
        case .duplicates: "Duplicados"
        case .spaceLens: "Mapa do disco"
        case .uninstaller: "Desinstalar apps"
        case .leftovers: "Restos de apps"
        case .startup: "Inicialização"
        case .monitor: "Monitor"
        case .maintenance: "Manutenção"
        case .settings: "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "sparkle"
        case .junk: "trash"
        case .projects: "chevron.left.forwardslash.chevron.right"
        case .largeFiles: "doc.badge.arrow.up"
        case .duplicates: "square.on.square"
        case .spaceLens: "chart.pie"
        case .uninstaller: "xmark.app"
        case .leftovers: "puzzlepiece.extension"
        case .startup: "power"
        case .monitor: "waveform.path.ecg"
        case .maintenance: "wrench.and.screwdriver"
        case .settings: "gearshape"
        }
    }

    enum Group: String, CaseIterable {
        case start = ""
        case cleanup = "Limpeza"
        case space = "Espaço"
        case apps = "Apps"
        case performance = "Desempenho"
        case app = "Lustro"

        var routes: [Route] {
            switch self {
            case .start: [.overview]
            case .cleanup: [.junk, .projects, .largeFiles, .duplicates]
            case .space: [.spaceLens]
            case .apps: [.uninstaller, .leftovers]
            case .performance: [.monitor, .startup, .maintenance]
            case .app: [.settings]
            }
        }
    }
}
