import Foundation

/// A JSON document that keeps what `JSONSerialization` throws away: the order of keys
/// and the exact spelling of numbers. Editing someone else's config file (Claude Code's
/// `settings.json`) through it changes only what was meant to change.
public enum JSONValue: Equatable, Sendable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    /// Kept as written (`1`, `1.0`, `1e3`) so a round trip doesn't reformat it.
    case number(String)
    case bool(Bool)
    case null

    public subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let values) = self { return values }
        return nil
    }

    public var objectValue: [JSONMember]? {
        if case .object(let members) = self { return members }
        return nil
    }
}

public struct JSONMember: Equatable, Sendable {
    public var key: String
    public var value: JSONValue

    public init(_ key: String, _ value: JSONValue) {
        self.key = key
        self.value = value
    }
}

public extension [JSONMember] {
    /// Replaces the value in place (keeping its position), or appends it.
    mutating func set(_ key: String, _ value: JSONValue) {
        if let index = firstIndex(where: { $0.key == key }) {
            self[index].value = value
        } else {
            append(JSONMember(key, value))
        }
    }

    mutating func remove(_ key: String) {
        removeAll { $0.key == key }
    }
}

// MARK: Parsing

public struct JSONParseError: Error, Equatable, Sendable {
    /// Line and column (1-based) where the parser gave up.
    public let line: Int
    public let column: Int
    public let reason: String
}

public extension JSONValue {
    static func parse(_ data: Data) throws(JSONParseError) -> JSONValue {
        var parser = JSONParser(bytes: Array(data))
        return try parser.document()
    }

    static func parse(_ text: String) throws(JSONParseError) -> JSONValue {
        try parse(Data(text.utf8))
    }
}

private struct JSONParser {
    let bytes: [UInt8]
    var index = 0
    var depth = 0

    init(bytes: [UInt8]) {
        // A byte-order mark isn't JSON, but editors write one; skip it.
        self.bytes = bytes
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { index = 3 }
    }

    mutating func document() throws(JSONParseError) -> JSONValue {
        skipWhitespace()
        let value = try self.value()
        skipWhitespace()
        guard index == bytes.count else { throw failure("conteúdo depois do fim do JSON") }
        return value
    }

    private mutating func value() throws(JSONParseError) -> JSONValue {
        guard index < bytes.count else { throw failure("o arquivo termina no meio") }
        switch bytes[index] {
        case UInt8(ascii: "{"): return try object()
        case UInt8(ascii: "["): return try array()
        case UInt8(ascii: "\""): return .string(try string())
        case UInt8(ascii: "t"): try literal("true"); return .bool(true)
        case UInt8(ascii: "f"): try literal("false"); return .bool(false)
        case UInt8(ascii: "n"): try literal("null"); return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): return .number(try number())
        default: throw failure("caractere inesperado")
        }
    }

    private mutating func object() throws(JSONParseError) -> JSONValue {
        try enter()
        defer { depth -= 1 }
        index += 1
        var members: [JSONMember] = []
        skipWhitespace()
        if peek(UInt8(ascii: "}")) { index += 1; return .object(members) }
        while true {
            skipWhitespace()
            guard peek(UInt8(ascii: "\"")) else { throw failure("esperava o nome de uma chave") }
            let key = try string()
            skipWhitespace()
            guard peek(UInt8(ascii: ":")) else { throw failure("esperava \":\"") }
            index += 1
            skipWhitespace()
            members.append(JSONMember(key, try value()))
            skipWhitespace()
            if peek(UInt8(ascii: ",")) { index += 1; continue }
            if peek(UInt8(ascii: "}")) { index += 1; return .object(members) }
            throw failure("esperava \",\" ou \"}\"")
        }
    }

    private mutating func array() throws(JSONParseError) -> JSONValue {
        try enter()
        defer { depth -= 1 }
        index += 1
        var values: [JSONValue] = []
        skipWhitespace()
        if peek(UInt8(ascii: "]")) { index += 1; return .array(values) }
        while true {
            skipWhitespace()
            values.append(try value())
            skipWhitespace()
            if peek(UInt8(ascii: ",")) { index += 1; continue }
            if peek(UInt8(ascii: "]")) { index += 1; return .array(values) }
            throw failure("esperava \",\" ou \"]\"")
        }
    }

    private mutating func string() throws(JSONParseError) -> String {
        index += 1
        var scalars = String.UnicodeScalarView()
        var run = index
        func flush(_ end: Int) throws(JSONParseError) {
            guard run < end else { return }
            guard let piece = String(validating: bytes[run..<end], as: UTF8.self) else { throw failure("texto que não é UTF-8") }
            scalars.append(contentsOf: piece.unicodeScalars)
        }
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "\""):
                try flush(index)
                index += 1
                return String(scalars)
            case UInt8(ascii: "\\"):
                try flush(index)
                index += 1
                guard index < bytes.count else { break }
                let escape = bytes[index]
                index += 1
                switch escape {
                case UInt8(ascii: "\""): scalars.append("\"")
                case UInt8(ascii: "\\"): scalars.append("\\")
                case UInt8(ascii: "/"): scalars.append("/")
                case UInt8(ascii: "b"): scalars.append("\u{08}")
                case UInt8(ascii: "f"): scalars.append("\u{0C}")
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "u"): scalars.append(try unicodeEscape())
                default: throw failure("escape inválido")
                }
                run = index
            case 0..<0x20:
                throw failure("caractere de controle dentro de um texto")
            default:
                index += 1
            }
        }
        throw failure("texto sem aspas de fechamento")
    }

    private mutating func unicodeEscape() throws(JSONParseError) -> Unicode.Scalar {
        let high = try hex4()
        if (0xD800...0xDBFF).contains(high) {
            guard index + 1 < bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") else {
                throw failure("par substituto incompleto")
            }
            index += 2
            let low = try hex4()
            guard (0xDC00...0xDFFF).contains(low),
                  let scalar = Unicode.Scalar(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00))
            else { throw failure("par substituto inválido") }
            return scalar
        }
        guard let scalar = Unicode.Scalar(high) else { throw failure("par substituto inválido") }
        return scalar
    }

    private mutating func hex4() throws(JSONParseError) -> UInt32 {
        guard index + 4 <= bytes.count,
              let text = String(validating: bytes[index..<index + 4], as: UTF8.self),
              let value = UInt32(text, radix: 16)
        else { throw failure("escape \\u inválido") }
        index += 4
        return value
    }

    private mutating func number() throws(JSONParseError) -> String {
        let start = index
        if peek(UInt8(ascii: "-")) { index += 1 }
        guard digits() > 0 else { throw failure("número inválido") }
        if peek(UInt8(ascii: ".")) {
            index += 1
            guard digits() > 0 else { throw failure("número inválido") }
        }
        if peek(UInt8(ascii: "e")) || peek(UInt8(ascii: "E")) {
            index += 1
            if peek(UInt8(ascii: "+")) || peek(UInt8(ascii: "-")) { index += 1 }
            guard digits() > 0 else { throw failure("número inválido") }
        }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private mutating func digits() -> Int {
        let start = index
        while index < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[index]) { index += 1 }
        return index - start
    }

    private mutating func literal(_ word: String) throws(JSONParseError) {
        let expected = Array(word.utf8)
        guard index + expected.count <= bytes.count, Array(bytes[index..<index + expected.count]) == expected else {
            throw failure("palavra inválida")
        }
        index += expected.count
    }

    private mutating func enter() throws(JSONParseError) {
        depth += 1
        guard depth <= 512 else { throw failure("aninhamento fundo demais") }
    }

    private func peek(_ byte: UInt8) -> Bool {
        index < bytes.count && bytes[index] == byte
    }

    private mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[index]) { index += 1 }
    }

    private func failure(_ reason: String) -> JSONParseError {
        let upTo = bytes[..<min(index, bytes.count)]
        let line = upTo.count { $0 == 0x0A } + 1
        let column = (upTo.lastIndex(of: 0x0A).map { upTo.distance(from: $0, to: upTo.endIndex) } ?? upTo.count + 1)
        return JSONParseError(line: line, column: column, reason: reason)
    }
}

// MARK: Printing

public extension JSONValue {
    /// The layout a file was written with, so a rewrite looks like the original.
    struct Style: Equatable, Sendable {
        /// `nil` prints everything on one line with no spaces.
        public var indent: String?
        public var trailingNewline: Bool

        public init(indent: String? = "  ", trailingNewline: Bool = true) {
            self.indent = indent
            self.trailingNewline = trailingNewline
        }

        /// What Claude Code itself writes: `JSON.stringify(value, null, 2)`.
        public static let standard = Style()

        /// Guesses the indentation from the first indented line.
        public static func detect(in text: String) -> Style {
            let trailing = text.hasSuffix("\n")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains("\n") else {
                // `{}` alone says nothing about style; one line with content is minified.
                return trimmed.count <= 2 ? Style(trailingNewline: trailing || trimmed.isEmpty) : Style(indent: nil, trailingNewline: trailing)
            }
            for line in trimmed.split(separator: "\n", omittingEmptySubsequences: true).dropFirst() {
                let leading = line.prefix { $0 == " " || $0 == "\t" }
                if !leading.isEmpty { return Style(indent: String(leading), trailingNewline: trailing) }
            }
            return Style(trailingNewline: trailing)
        }
    }

    /// Printed the way `JSON.stringify` does it, so a file Claude Code wrote comes back
    /// byte for byte.
    func printed(_ style: Style = .standard) -> String {
        var out = ""
        write(to: &out, style: style, level: 0)
        if style.trailingNewline { out.append("\n") }
        return out
    }

    private func write(to out: inout String, style: Style, level: Int) {
        switch self {
        case .null: out.append("null")
        case .bool(let value): out.append(value ? "true" : "false")
        case .number(let text): out.append(text)
        case .string(let text): Self.writeString(text, to: &out)
        case .array(let values):
            guard !values.isEmpty else { out.append("[]"); return }
            out.append("[")
            for (offset, value) in values.enumerated() {
                if offset > 0 { out.append(",") }
                Self.newline(&out, style: style, level: level + 1)
                value.write(to: &out, style: style, level: level + 1)
            }
            Self.newline(&out, style: style, level: level)
            out.append("]")
        case .object(let members):
            guard !members.isEmpty else { out.append("{}"); return }
            out.append("{")
            for (offset, member) in members.enumerated() {
                if offset > 0 { out.append(",") }
                Self.newline(&out, style: style, level: level + 1)
                Self.writeString(member.key, to: &out)
                out.append(style.indent == nil ? ":" : ": ")
                member.value.write(to: &out, style: style, level: level + 1)
            }
            Self.newline(&out, style: style, level: level)
            out.append("}")
        }
    }

    private static func newline(_ out: inout String, style: Style, level: Int) {
        guard let indent = style.indent else { return }
        out.append("\n")
        for _ in 0..<level { out.append(indent) }
    }

    private static func writeString(_ text: String, to out: inout String) {
        out.append("\"")
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out.append("\\\"")
            case "\\": out.append("\\\\")
            case "\u{08}": out.append("\\b")
            case "\u{0C}": out.append("\\f")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                out.append("\\u" + String(repeating: "0", count: 4 - hex.count) + hex)
            default: out.unicodeScalars.append(scalar)
            }
        }
        out.append("\"")
    }
}
