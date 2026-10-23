/// The pages of the first-run tour, in order. Each has its own painting behind its
/// illustration, so moving forward feels like walking into a new room.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case disk
    case agenda
    case clipboard
    case tabs
    case shortcut
    case done

    var id: Int { rawValue }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }

    /// How far along the progress capsule is on this page.
    var progress: Double { Double(rawValue + 1) / Double(Self.allCases.count) }

    var palette: PaintPalette {
        switch self {
        case .welcome: .dusk
        case .disk: .forest
        case .agenda: .dawn
        case .clipboard: .night
        case .tabs: .sage
        case .shortcut: .plum
        case .done: .sunrise
        }
    }
}
