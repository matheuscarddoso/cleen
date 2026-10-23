enum FileSort: String, CaseIterable, Identifiable {
    case size
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: String(localized: "Maiores primeiro")
        case .oldest: String(localized: "Sem uso há mais tempo")
        }
    }
}
