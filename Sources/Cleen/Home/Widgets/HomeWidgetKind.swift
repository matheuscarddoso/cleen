/// Everything that can go on Início. Which ones show, in what order and at what size is
/// the person's call (see `HomeLayout`).
enum HomeWidgetKind: String, Codable, CaseIterable, Identifiable {
    case nowPlaying
    case agenda
    case mirror
    case disk
    case aiUsage
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Tocando agora"
        case .agenda: "Agenda"
        case .mirror: "Espelho"
        case .disk: "Disco"
        case .aiUsage: "Uso de IA"
        case .system: "Sistema"
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
        }
    }

    var defaultSize: HomeWidgetSize {
        switch self {
        case .nowPlaying: .large
        case .agenda, .disk, .aiUsage, .system: .medium
        case .mirror: .small
        }
    }

    /// Lists and text stretch into leftover room; artwork, rings and the camera keep
    /// their shape.
    func isFlexible(at size: HomeWidgetSize) -> Bool {
        switch self {
        case .agenda, .aiUsage, .system: size != .small
        case .nowPlaying, .mirror, .disk: false
        }
    }
}
