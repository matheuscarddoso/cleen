import Foundation

extension Locale {
    /// Lustro speaks Brazilian Portuguese, so numbers and dates follow it too, whatever
    /// the system region is ("7,4 GB", not "7.4 GB" next to Portuguese text).
    public static let lustro = Locale(identifier: "pt_BR")
}

extension Int64 {
    /// `12,4 GB` — decimal units, matching Finder.
    public var bytes: String { formatted(.byteCount(style: .file).locale(.lustro)) }

    /// `6,33 GB` in binary units, matching Activity Monitor's memory figures.
    public var memoryBytes: String { formatted(.byteCount(style: .memory).locale(.lustro)) }
}
