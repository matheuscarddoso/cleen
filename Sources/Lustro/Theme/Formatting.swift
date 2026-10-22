import Foundation
import LustroKit

extension Double {
    /// Bytes per second as `1,2 MB/s`.
    var rate: String { "\(Int64(self).bytes)/s" }

    /// `0.42` → `42%`.
    var percent: String { formatted(.percent.precision(.fractionLength(0)).locale(.lustro)) }

    /// A process's CPU share, already in percent: one decimal below 10, none above.
    var cpuPercent: String {
        formatted(.number.precision(.fractionLength(self < 10 ? 1 : 0)).locale(.lustro)) + "%"
    }
}

extension Int {
    /// `12.345`
    var counted: String { formatted(.number.locale(.lustro)) }
}

extension Date {
    /// "há 3 meses", "ontem".
    var relative: String {
        formatted(.relative(presentation: .named, unitsStyle: .wide).locale(.lustro))
    }
}

extension Array where Element == String {
    /// `a, b e c`
    var listed: String { formatted(.list(type: .and).locale(.lustro)) }
}
