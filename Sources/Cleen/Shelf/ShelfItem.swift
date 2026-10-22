import Foundation

/// A file parked on the shelf. Only a reference: the file stays where it is.
struct ShelfItem: Identifiable, Hashable, Codable {
    var id: URL { url }
    let url: URL
    let added: Date
}
