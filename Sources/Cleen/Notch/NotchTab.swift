/// The tools in the notch's tab bar. Which ones show, and in what order, is set in
/// Ajustes › Abas (see `TabPreferences`).
enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case home
    case calendar
    case shelf
    case clipboard
    case screenshots
    case ai
    case timer
    case notes
    case reminders
    case converter
    case emoji
    case weather
    case shortcuts
    case overview
    case clean
    case projects
    case files
    case duplicates
    case space
    case apps
    case leftovers
    case system
    case startup
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Cleen"
        case .calendar: "Calendário"
        case .shelf: "Shelf"
        case .clipboard: "Área de transferência"
        case .screenshots: "Screenshots"
        case .ai: "Uso de IA"
        case .timer: "Timer"
        case .notes: "Notas"
        case .reminders: "Lembretes"
        case .converter: "Conversor"
        case .emoji: "Emoji"
        case .weather: "Tempo"
        case .shortcuts: "Atalhos"
        case .overview: "Visão geral"
        case .clean: "Limpeza"
        case .projects: "Projetos"
        case .files: "Arquivos grandes"
        case .duplicates: "Duplicados"
        case .space: "Mapa do disco"
        case .apps: "Desinstalar apps"
        case .leftovers: "Restos de apps"
        case .system: "Sistema"
        case .startup: "Inicialização"
        case .maintenance: "Manutenção"
        }
    }

    /// Name in the Abas settings list (Home reads better there than the app's name).
    var settingsTitle: String { self == .home ? "Início" : title }

    var symbol: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .calendar: "calendar"
        case .shelf: "tray.and.arrow.down.fill"
        case .clipboard: "doc.on.clipboard"
        case .screenshots: "camera.viewfinder"
        case .ai: "chart.bar.xaxis"
        case .timer: "timer"
        case .notes: "note.text"
        case .reminders: "checklist"
        case .converter: "arrow.left.arrow.right"
        case .emoji: "face.smiling"
        case .weather: "cloud.sun"
        case .shortcuts: "square.2.layers.3d"
        case .overview: "internaldrive.fill"
        case .clean: "trash"
        case .projects: "chevron.left.forwardslash.chevron.right"
        case .files: "doc.fill"
        case .duplicates: "square.on.square"
        case .space: "chart.pie"
        case .apps: "xmark.app"
        case .leftovers: "puzzlepiece.extension"
        case .system: "chart.bar.fill"
        case .startup: "power"
        case .maintenance: "wrench.and.screwdriver.fill"
        }
    }

    /// Tools added after the first release start out of the bar, so an update never
    /// crowds it; they're one switch away in Ajustes › Abas.
    var isHiddenByDefault: Bool {
        switch self {
        case .timer, .notes, .reminders, .converter, .emoji, .weather, .shortcuts: true
        default: false
        }
    }
}
