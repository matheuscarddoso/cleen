/// How much of the Início row a widget takes. The widths are fixed so a layout reads
/// the same every time it opens; flexible widgets share whatever room is left.
enum HomeWidgetSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var width: Double {
        switch self {
        case .small: 88
        case .medium: 180
        case .large: 270
        }
    }

    /// The letter on the size switch in edit mode.
    var shortLabel: String {
        switch self {
        case .small: "P"
        case .medium: "M"
        case .large: "G"
        }
    }

    var label: String {
        switch self {
        case .small: "Pequeno"
        case .medium: "Médio"
        case .large: "Grande"
        }
    }
}
