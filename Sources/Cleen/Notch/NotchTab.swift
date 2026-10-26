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
    case agents
    case messages
    case icons
    case stocks
    case teleprompter
    case recorder
    case assistant
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
        case .calendar: String(localized: "Calendário")
        case .shelf: String(localized: "Shelf")
        case .clipboard: String(localized: "Área de transferência")
        case .screenshots: String(localized: "Screenshots")
        case .ai: String(localized: "Uso de IA")
        case .timer: String(localized: "Timer")
        case .notes: String(localized: "Notas")
        case .reminders: String(localized: "Lembretes")
        case .converter: String(localized: "Conversor")
        case .emoji: String(localized: "Emoji")
        case .weather: String(localized: "Tempo")
        case .shortcuts: String(localized: "Atalhos")
        case .agents: String(localized: "Agentes")
        case .messages: String(localized: "Mensagens")
        case .icons: String(localized: "Ícones")
        case .stocks: String(localized: "Ações")
        case .teleprompter: String(localized: "Teleprompter")
        case .recorder: String(localized: "Gravar")
        case .assistant: String(localized: "Perguntar")
        case .overview: String(localized: "Visão geral")
        case .clean: String(localized: "Limpeza")
        case .projects: String(localized: "Projetos")
        case .files: String(localized: "Arquivos grandes")
        case .duplicates: String(localized: "Duplicados")
        case .space: String(localized: "Mapa do disco")
        case .apps: String(localized: "Desinstalar apps")
        case .leftovers: String(localized: "Restos de apps")
        case .system: String(localized: "Sistema")
        case .startup: String(localized: "Inicialização")
        case .maintenance: String(localized: "Manutenção")
        }
    }

    /// Name in the Abas settings list (Home reads better there than the app's name).
    var settingsTitle: String { self == .home ? String(localized: "Início") : title }

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
        case .agents: "asterisk"
        case .messages: "message.fill"
        case .icons: "square.grid.3x3.square"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .teleprompter: "text.aligncenter"
        case .recorder: "record.circle"
        case .assistant: "bubble.left.and.text.bubble.right"
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
        case .timer, .notes, .reminders, .converter, .emoji, .weather, .shortcuts, .icons, .stocks, .teleprompter, .assistant: true
        // Shown right away to people who use Claude Code: that's who it's for.
        case .agents: !AgentsModel.isClaudeCodeInstalled
        default: false
        }
    }
}
