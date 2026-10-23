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
        case .small: String(localized: "P", comment: "Initial of the small widget size")
        case .medium: String(localized: "M", comment: "Initial of the medium widget size")
        case .large: String(localized: "G", comment: "Initial of the large widget size")
        }
    }

    var label: String {
        switch self {
        case .small: String(localized: "Pequeno")
        case .medium: String(localized: "Médio")
        case .large: String(localized: "Grande")
        }
    }
}
