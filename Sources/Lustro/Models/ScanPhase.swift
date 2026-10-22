/// Lifecycle shared by every scanning section.
enum ScanPhase: Equatable {
    case idle
    case scanning
    case ready
}
