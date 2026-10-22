import Foundation

/// An error that already carries the sentence to show.
struct UserFacingError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        errorDescription = message
    }
}
