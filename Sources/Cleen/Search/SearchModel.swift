import AppKit
import CleenKit
import Observation
import SwiftUI

/// The notch's launcher (⌥Space): apps, window placement, Cleen's tools, the clipboard
/// history, emoji, a calculator. Results are recomputed on every keystroke from lists
/// already in memory, so typing never waits on the disk.
@Observable
final class SearchModel {
    var query = "" {
        didSet { if query != oldValue { recompute() } }
    }
    var selection = 0
    private(set) var sections: [SearchSection] = []

    @ObservationIgnored private var apps: [AppEntry] = []
    @ObservationIgnored private var appItems: [SearchItem] = []
    @ObservationIgnored private var commands: [SearchItem] = []
    @ObservationIgnored private var usage: [String: Usage]
    @ObservationIgnored private unowned let app: AppModel

    private static let usageKey = "searchUsage"

    /// How often and how lately something was run: it floats up the list.
    private struct Usage: Codable {
        var count: Int
        var last: Date
    }

    init(app: AppModel) {
        self.app = app
        let data = UserDefaults.standard.data(forKey: Self.usageKey)
        usage = data.flatMap { try? JSONDecoder().decode([String: Usage].self, from: $0) } ?? [:]
    }

    /// Flattened, in display order, for the arrow keys.
    var items: [SearchItem] { sections.flatMap(\.items) }

    var selectedItem: SearchItem? {
        let all = items
        return all.indices.contains(selection) ? all[selection] : all.first
    }

    /// Called each time the search opens: fresh query, apps rescanned in the background.
    func prepare() {
        query = ""
        selection = 0
        commands = SearchCatalog.windows() + SearchCatalog.tools(live: app.live) + SearchCatalog.tabs()
        recompute()
        Task {
            let apps = await offMain { AppIndex.scan() }
            guard apps != self.apps else { return }
            self.apps = apps
            self.appItems = apps.map { entry in
                SearchItem(id: "app.\(entry.id)", title: entry.name, icon: .app(entry.url), kind: String(localized: "App")) {
                    NSWorkspace.shared.openApplication(at: entry.url, configuration: .init())
                    return .close
                }
            }
            recompute()
        }
        Task {
            let wasLoaded = EmojiModel.shared.isLoaded
            await EmojiModel.shared.load()
            if !wasLoaded { recompute() }
        }
    }

    func move(_ offset: Int) {
        let count = items.count
        guard count > 0 else { return }
        selection = (selection + offset + count) % count
    }

    /// Runs an item and reports what the notch should do next.
    func run(_ item: SearchItem) -> SearchItem.Outcome {
        var entry = usage[item.id] ?? Usage(count: 0, last: .now)
        entry.count += 1
        entry.last = .now
        usage[item.id] = entry
        if let data = try? JSONEncoder().encode(usage) { UserDefaults.standard.set(data, forKey: Self.usageKey) }
        return item.action()
    }

    // MARK: Results

    private func recompute() {
        selection = 0
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            sections = suggestions()
            return
        }
        var sections: [SearchSection] = []
        if let calculation = calculation(text) {
            sections.append(SearchSection(title: String(localized: "Calculadora"), items: [calculation]))
        }
        let ranked = rank(appItems + commands, for: text)
        if !ranked.isEmpty {
            sections.append(SearchSection(title: String(localized: "Resultados"), items: Array(ranked.prefix(12))))
        }
        if text.count >= 2 {
            let clips = clipboardMatches(text)
            if !clips.isEmpty { sections.append(SearchSection(title: String(localized: "Área de transferência"), items: clips)) }
            let emoji = emojiMatches(text)
            if !emoji.isEmpty { sections.append(SearchSection(title: String(localized: "Emoji"), items: emoji)) }
        }
        self.sections = sections
    }

    /// Best first: how well it matches, nudged by how often and how lately it ran.
    private func rank(_ candidates: [SearchItem], for text: String) -> [SearchItem] {
        let scored = candidates.compactMap { item -> (item: SearchItem, match: Double, total: Double)? in
            guard let score = FuzzyMatch.score(text, title: item.title, keywords: item.keywords) else { return nil }
            return (item, score, score + boost(item.id))
        }
        // Letters merely in order ("rir" in "Print Center") only count when nothing
        // matches better.
        let strong = scored.filter { $0.match >= 0.5 }
        return (strong.isEmpty ? scored : strong).sorted { $0.total > $1.total }.map(\.item)
    }

    private func boost(_ id: String) -> Double {
        guard let entry = usage[id] else { return 0 }
        let days = Date.now.timeIntervalSince(entry.last) / 86_400
        return min(0.25, log2(Double(entry.count) + 1) * 0.05) * exp(-days / 14)
    }

    /// With nothing typed: what you run most, then a few starting points.
    private func suggestions() -> [SearchSection] {
        let everything = appItems + commands
        let recent = usage
            .sorted { lhs, rhs in boost(lhs.key) > boost(rhs.key) }
            .compactMap { pair in everything.first { $0.id == pair.key } }
            .prefix(6)
        let starters = ["window.leftHalf", "window.rightHalf", "window.maximize", "tool.colorPicker", "tool.clipboard", "tool.emoji"]
            .compactMap { id in commands.first { $0.id == id } }
            .filter { item in !recent.contains { $0.id == item.id } }
        var sections: [SearchSection] = []
        if !recent.isEmpty { sections.append(SearchSection(title: String(localized: "Recentes"), items: Array(recent))) }
        sections.append(SearchSection(title: String(localized: "Sugestões"), items: Array(starters.prefix(6 - min(recent.count, 3)))))
        return sections
    }

    private func calculation(_ text: String) -> SearchItem? {
        let separator = Locale.cleen.decimalSeparator?.first ?? "."
        guard let value = Calculator.evaluate(text, decimalSeparator: separator) else { return nil }
        let result = value.formatted(.number.precision(.fractionLength(0...10)).locale(.cleen))
        return SearchItem(id: "calc", title: result, subtitle: text, icon: .symbol("equal", ToolPalette.orange), kind: String(localized: "Copiar")) {
            SearchPaste.put(result)
            return .close
        }
    }

    private func clipboardMatches(_ text: String) -> [SearchItem] {
        app.clipboard.log.entries
            .filter { ($0.kind == .text || $0.kind == .link) && FuzzyMatch.fold($0.text ?? "").contains(FuzzyMatch.fold(text)) }
            .prefix(3)
            .map { entry in
                let line = (entry.text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                return SearchItem(id: "clip.\(entry.id)", title: line, subtitle: entry.sourceName, icon: .symbol(entry.kind == .link ? "link" : "text.alignleft", ToolPalette.indigo),
                                  kind: String(localized: "Colar")) { [clipboard = app.clipboard] in
                    clipboard.copy(entry)
                    return .closeAndPaste
                }
            }
    }

    private func emojiMatches(_ text: String) -> [SearchItem] {
        EmojiModel.shared.matches(text, limit: 4).map { item in
            SearchItem(id: "emoji.\(item.emoji)", title: item.name, icon: .emoji(item.emoji), kind: String(localized: "Colar")) {
                EmojiModel.shared.noteUsed(item)
                SearchPaste.put(item.emoji)
                return .closeAndPaste
            }
        }
    }
}
