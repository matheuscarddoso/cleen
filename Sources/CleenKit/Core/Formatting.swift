import Foundation

extension Locale {
    /// Numbers, dates and times follow the Mac's own language and region, and change
    /// with them while Cleen runs (24-hour clock, decimal comma, first weekday…).
    public static var cleen: Locale { .autoupdatingCurrent }
}

extension Int64 {
    /// `12,4 GB` — decimal units, matching Finder.
    public var bytes: String { formatted(.byteCount(style: .file).locale(.cleen)) }

    /// `6,33 GB` in binary units, matching Activity Monitor's memory figures.
    public var memoryBytes: String { formatted(.byteCount(style: .memory).locale(.cleen)) }
}
