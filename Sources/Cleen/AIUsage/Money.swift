import CleenKit
import Foundation

extension Double {
    /// `US$ 410,35`
    var dollars: String {
        formatted(.currency(code: "USD").precision(.fractionLength(self < 1000 ? 2 : 0)).locale(.cleen))
    }
}

extension Int {
    /// `12,3 mi` tokens, `840 mil`.
    var tokens: String {
        formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(.cleen))
    }
}
