/// Everything that can go on Início. Which ones show, in what order and at what size is
/// the person's call (see `HomeLayout`).
enum HomeWidgetKind: String, Codable, CaseIterable, Identifiable {
    case nowPlaying
    case agenda
    case mirror
    case disk
    case aiUsage
    case system
    case timer
    case note
    case reminders
    case weather
    case agents
    case stocks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: String(localized: "Tocando agora")
        case .agenda: String(localized: "Agenda")
        case .mirror: String(localized: "Espelho")
        case .disk: String(localized: "Disco")
        case .aiUsage: String(localized: "Uso de IA")
        case .system: String(localized: "Sistema")
        case .timer: String(localized: "Timer")
        case .note: String(localized: "Nota")
        case .reminders: String(localized: "Lembretes")
        case .weather: String(localized: "Tempo")
        case .agents: String(localized: "Claude Code")
        case .stocks: String(localized: "Ações")
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "play.circle"
        case .agenda: "calendar"
        case .mirror: "web.camera"
        case .disk: "internaldrive"
        case .aiUsage: "chart.bar.xaxis"
        case .system: "cpu"
        case .timer: "timer"
        case .note: "note.text"
        case .reminders: "checklist"
        case .weather: "cloud.sun"
        case .agents: "asterisk"
        case .stocks: "chart.line.uptrend.xyaxis"
        }
    }

    /// The sizes the widget has a real layout for, smallest first.
    var sizes: [HomeWidgetSize] {
        switch self {
        case .nowPlaying: [.small, .medium, .large]
        case .agenda: [.small, .medium, .large]
        case .mirror: [.small, .medium]
        case .disk: [.small, .medium]
        case .aiUsage: [.small, .medium]
        case .system: [.small, .medium]
        case .timer: [.small, .medium]
        case .note: [.medium, .large]
        case .reminders: [.medium, .large]
        case .weather: [.small, .medium, .large]
        case .agents: [.small, .medium, .large]
        case .stocks: [.medium, .large]
        }
    }

    var defaultSize: HomeWidgetSize {
        switch self {
        case .nowPlaying: .large
        case .agenda, .disk, .aiUsage, .system, .note, .reminders, .weather, .agents, .stocks: .medium
        case .mirror, .timer: .small
        }
    }

    /// Lists and text stretch into leftover room; artwork, rings and the camera keep
    /// their shape.
    func isFlexible(at size: HomeWidgetSize) -> Bool {
        switch self {
        case .agenda, .aiUsage, .system, .note, .reminders, .weather, .agents, .stocks: size != .small
        case .nowPlaying, .mirror, .disk, .timer: false
        }
    }
}
