import Foundation

/// Arithmetic typed into the search: `12*3,5`, `(200 + 15%) / 2`, `2^10`, `1.250 x 4`.
/// A tiny recursive-descent parser instead of NSExpression, which raises Objective-C
/// exceptions (crashes) on malformed input.
public enum Calculator {
    /// nil unless the text is a calculation (a lone number isn't one).
    public static func evaluate(_ text: String, decimalSeparator: Character = ".") -> Double? {
        var parser = Parser(tokens: tokenize(text, decimalSeparator: decimalSeparator) ?? [])
        guard parser.tokens.contains(where: \.isOperator), let value = parser.expression(), parser.isAtEnd, value.isFinite else { return nil }
        return value
    }

    enum Token: Equatable {
        case number(Double)
        case op(Character)
        case open, close
        case percent

        var isOperator: Bool {
            if case .op = self { return true }
            return self == .percent
        }
    }

    static func tokenize(_ text: String, decimalSeparator: Character) -> [Token]? {
        var tokens: [Token] = []
        var number = ""
        func flush() -> Bool {
            guard !number.isEmpty else { return true }
            defer { number = "" }
            guard let value = parseNumber(number, decimalSeparator: decimalSeparator) else { return false }
            tokens.append(.number(value))
            return true
        }
        for character in text {
            if character.isNumber || character == "." || character == "," {
                number.append(character)
                continue
            }
            guard flush() else { return nil }
            switch character {
            case " ": continue
            case "+", "-", "*", "/", "^": tokens.append(.op(character))
            case "x", "X", "×": tokens.append(.op("*"))
            case "÷": tokens.append(.op("/"))
            case "(": tokens.append(.open)
            case ")": tokens.append(.close)
            case "%": tokens.append(.percent)
            default: return nil
            }
        }
        return flush() ? tokens : nil
    }

    /// `1.250,5` or `1,250.5` both read as 1250.5; a single separator is the decimal one
    /// unless it's followed by exactly three digits in the locale's grouping style.
    static func parseNumber(_ raw: String, decimalSeparator: Character) -> Double? {
        let grouping: Character = decimalSeparator == "," ? "." : ","
        var text = raw
        if text.contains(decimalSeparator) && text.contains(grouping) {
            text = text.replacingOccurrences(of: String(grouping), with: "")
        } else if let only = text.firstIndex(of: grouping), text.filter({ $0 == grouping }).count == 1,
                  text.distance(from: only, to: text.endIndex) != 4 {
            // "3,5" with a "." locale is still three and a half.
            text = text.replacingOccurrences(of: String(grouping), with: String(decimalSeparator))
        } else {
            text = text.replacingOccurrences(of: String(grouping), with: "")
        }
        return Double(text.replacingOccurrences(of: String(decimalSeparator), with: "."))
    }

    private struct Parser {
        var tokens: [Token]
        var position = 0

        var isAtEnd: Bool { position == tokens.count }
        private var current: Token? { position < tokens.count ? tokens[position] : nil }

        // expression := term (("+" | "-") term)*
        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while case .op(let op)? = current, op == "+" || op == "-" {
                position += 1
                guard var right = term() else { return nil }
                // `200 + 15%` means 15% of 200, as on a calculator.
                if case .percent? = current { position += 1; right = value * right / 100 }
                value = op == "+" ? value + right : value - right
            }
            return value
        }

        // term := power (("*" | "/") power)*
        mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while case .op(let op)? = current, op == "*" || op == "/" {
                position += 1
                guard let right = power() else { return nil }
                if op == "/" && right == 0 { return nil }
                value = op == "*" ? value * right : value / right
            }
            return value
        }

        // power := unary ("^" power)?
        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if case .op("^")? = current {
                position += 1
                guard let exponent = power() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        // unary := "-" unary | primary "%"?
        mutating func unary() -> Double? {
            if case .op("-")? = current {
                position += 1
                return unary().map { -$0 }
            }
            guard var value = primary() else { return nil }
            // A percent not after + or - is a plain fraction: `10% * 50`.
            if case .percent? = current, !followsAddition { position += 1; value /= 100 }
            return value
        }

        mutating func primary() -> Double? {
            switch current {
            case .number(let value)?:
                position += 1
                return value
            case .open?:
                position += 1
                guard let value = expression(), current == .close else { return nil }
                position += 1
                return value
            default:
                return nil
            }
        }

        /// Whether the number just read is the right side of + or −, where % is relative.
        private var followsAddition: Bool {
            guard position >= 2, case .op(let op) = tokens[position - 2] else { return false }
            return op == "+" || op == "-"
        }
    }
}
