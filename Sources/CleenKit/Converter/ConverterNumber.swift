import Foundation

/// Reading what someone typed and writing results back, the Brazilian way: comma for
/// decimals, dot for thousands.
public enum ConverterNumber {
    /// Parses "1.234,56", "1234,56", "0,5", "-3" and also the dot-decimal "1.5" people
    /// type out of habit. Returns nil for empty or non-numeric text.
    ///
    /// The rules: with both separators, the last one is the decimal mark. A lone comma
    /// is decimal. Dots alone are thousands when every group after them has exactly
    /// three digits ("1.000", "2.500.000") and decimal otherwise ("1.5", "0.25").
    public static func parse(_ text: String) -> Double? {
        var raw = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "−", with: "-")
        guard !raw.isEmpty else { return nil }
        var sign = 1.0
        if raw.hasPrefix("-") {
            sign = -1
            raw.removeFirst()
        } else if raw.hasPrefix("+") {
            raw.removeFirst()
        }
        guard !raw.isEmpty, raw.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }) else { return nil }

        let lastComma = raw.lastIndex(of: ",")
        let lastDot = raw.lastIndex(of: ".")
        let normalized: String
        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            let decimalIsComma = comma > dot
            let grouping: Character = decimalIsComma ? "." : ","
            let decimal: Character = decimalIsComma ? "," : "."
            let parts = raw.split(separator: decimal, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            normalized = parts[0].filter { $0 != grouping } + "." + parts[1]
        case (_?, nil):
            let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            normalized = parts[0] + "." + parts[1]
        case (nil, _?):
            let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
            let isGrouping = parts.count > 1 && !parts[0].isEmpty && parts.dropFirst().allSatisfy { $0.count == 3 }
            if isGrouping {
                normalized = parts.joined()
            } else {
                guard parts.count == 2 else { return nil }
                normalized = parts[0] + "." + parts[1]
            }
        case (nil, nil):
            normalized = raw
        }
        guard normalized != ".", let value = Double(normalized.hasPrefix(".") ? "0" + normalized : normalized) else { return nil }
        return sign * value
    }

    /// A result as people read it: "1,6093", "12.345,7", "0,0006214", "1,23e-9".
    ///
    /// Around six significant digits, never trailing zeros. Money always shows cents
    /// (unless the amount is smaller than a cent).
    public static func format(_ value: Double, isCurrency: Bool = false, locale: Locale = .cleen) -> String {
        guard value.isFinite else { return "—" }
        if value == 0 { return "0" }
        let magnitude = abs(value)
        if magnitude >= 1e15 || magnitude < 1e-9 {
            return value.formatted(.number.notation(.scientific).precision(.significantDigits(1...4)).locale(locale))
        }
        if isCurrency, magnitude >= 0.01 {
            return value.formatted(.number.precision(.fractionLength(2)).locale(locale))
        }
        if magnitude >= 1 {
            let integerDigits = Int(log10(magnitude)) + 1
            let fraction = max(0, min(4, 6 - integerDigits))
            return value.formatted(.number.precision(.fractionLength(0...fraction)).locale(locale))
        }
        return value.formatted(.number.precision(.significantDigits(1...4)).locale(locale))
    }
}
