enum FileSort: String, CaseIterable, Identifiable {
    case size
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: "Maiores primeiro"
        case .oldest: "Sem uso há mais tempo"
        }
    }
}
