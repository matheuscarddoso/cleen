import Foundation

/// A tile's look, derived from the shortcut's name: the CLI gives no icon, so the name
/// picks a glyph (by meaning when a word gives one away, by hash otherwise) and a color.
/// Both are stable across launches and machines, unlike `hashValue`.
public struct ShortcutGlyph: Sendable, Equatable {
    public let symbol: String
    /// An index into the app's tile palette, `0..<paletteCount`.
    public let colorIndex: Int

    public init(name: String, paletteCount: Int) {
        let hash = Self.fnv1a(ShortcutText.normalized(name))
        symbol = Self.meaningfulSymbol(for: name) ?? Self.fallbackSymbols[Int((hash >> 17) % UInt64(Self.fallbackSymbols.count))]
        colorIndex = paletteCount > 0 ? Int(hash % UInt64(paletteCount)) : 0
    }

    /// Words (Portuguese and English) that say what a shortcut does, and the SF Symbol
    /// for it. A word matches when it starts with the key.
    static let keywords: [(keys: [String], symbol: String)] = [
        (["shazam", "music", "musica", "song", "spotify", "playlist", "tocar"], "music.note"),
        (["photo", "foto", "image", "imagem", "imagens", "screenshot", "captura", "camera"], "photo"),
        (["text", "texto", "mensag", "message", "sms", "whatsapp", "imessage"], "text.bubble"),
        (["mail", "email"], "envelope"),
        (["break", "pausa", "cafe", "coffee", "descanso"], "cup.and.saucer"),
        (["timer", "pomodoro", "alarm", "alarme", "cronometro"], "timer"),
        (["focus", "foco", "dormir", "sleep"], "moon"),
        (["wifi", "network", "rede"], "wifi"),
        (["bluetooth", "airpods", "fone", "headphone"], "headphones"),
        (["light", "luz", "luzes", "lamp", "lampada"], "lightbulb"),
        (["home", "casa"], "house"),
        (["calendar", "agenda", "evento", "event", "meeting", "reuniao"], "calendar"),
        (["note", "nota", "notas"], "note.text"),
        (["translat", "traduz", "traduc"], "character.bubble"),
        (["weather", "clima", "previsao"], "cloud.sun"),
        (["battery", "bateria"], "battery.75percent"),
        (["volume", "sound", "audio"], "speaker.wave.2"),
        (["pdf", "file", "arquivo", "document", "documento"], "doc"),
        (["folder", "pasta"], "folder"),
        (["clipboard", "copiar", "copy", "colar", "paste"], "doc.on.clipboard"),
        (["web", "safari", "url", "link", "site", "browser"], "globe"),
        (["map", "mapa", "rota", "route", "direction"], "map"),
        (["car", "carro", "drive"], "car"),
        (["workout", "treino", "corrida", "exercise"], "figure.run"),
        (["water", "agua"], "drop"),
        (["lock", "bloquear", "trancar"], "lock"),
        (["remind", "lembrete", "tarefa"], "checklist"),
        (["call", "ligar", "phone", "telefone"], "phone"),
        (["dark", "escuro", "aparencia", "appearance"], "circle.lefthalf.filled"),
    ]

    static let fallbackSymbols = [
        "sparkles", "bolt.fill", "wand.and.stars", "square.stack.3d.up", "command",
        "paperplane", "star", "flag", "bookmark", "gearshape", "square.2.layers.3d", "circle.hexagongrid",
    ]

    static func meaningfulSymbol(for name: String) -> String? {
        let words = ShortcutText.words(name)
        for entry in keywords {
            // Short keys ("car", "web", "url") must be the whole word, or "cartão" turns
            // into a car.
            let matches = entry.keys.contains { key in
                words.contains { key.count <= 3 ? $0 == key : $0.hasPrefix(key) }
            }
            if matches { return entry.symbol }
        }
        return nil
    }

    private static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
