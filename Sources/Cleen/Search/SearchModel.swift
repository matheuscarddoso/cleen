import AppKit
import CleenKit
import Observation
import SwiftUI

/// The notch's launcher (⌥Space): apps, open windows, files, window placement, Cleen's
/// tools, the Mac's commands, quick links, snippets, today's events, the clipboard
/// history, emoji, and a calculator that also converts units, currencies, time zones
/// and dates. Typing never waits on the disk: everything but files (Spotlight, which
/// answers a moment later) comes from lists already in memory.
@Observable
final class SearchModel {
    /// What the list is narrowed to.
    enum Mode: Equatable {
        case all
        case files
        case windows

        var title: String {
            switch self {
            case .all: ""
            case .files: String(localized: "Arquivos")
            case .windows: String(localized: "Janelas")
            }
        }

        var placeholder: String {
            switch self {
            case .all: String(localized: "Buscar apps, arquivos, janelas, comandos…")
            case .files: String(localized: "Nome do arquivo…")
            case .windows: String(localized: "Título da janela ou nome do app…")
            }
        }
    }

    /// The ⌘K panel turned into a small editor for the selected item.
    enum Editing: Equatable {
        case alias(id: String, title: String)
        case hotKey(id: String, title: String)
    }

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            showsActions = false
            recompute()
        }
    }
    var selection = 0
    private(set) var mode = Mode.all
    private(set) var sections: [SearchSection] = []

    /// ⌘K: the selected item's other actions.
    var showsActions = false {
        didSet {
            actionSelection = 0
            if !showsActions { editing = nil }
        }
    }
    var actionSelection = 0
    private(set) var editing: Editing? {
        didSet { if editing == nil { stopRecording() } }
    }
    /// Shown under the shortcut recorder: "Use ⌘, ⌃ ou ⌥", "Em uso por outro app".
    private(set) var recorderMessage: String?

    let library = SearchLibrary()
    let files = FileSearch()

    @ObservationIgnored private var apps: [AppEntry] = []
    @ObservationIgnored private var appItems: [SearchItem] = []
    @ObservationIgnored private var commands: [SearchItem] = []
    @ObservationIgnored private var openWindows: [OpenWindow] = []
    @ObservationIgnored private var usage: [String: Usage]
    @ObservationIgnored private let hotKeys = SearchHotKeys()
    @ObservationIgnored private(set) lazy var expander = SnippetExpander(library: library)
    @ObservationIgnored private var recorder: Any?
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
        files.onChange = { [weak self] in self?.recompute(keepingSelection: true) }
        library.onHotKeysChange = { [weak self] in self?.syncHotKeys() }
        library.onSnippetsChange = { [weak self] in self?.expander.update() }
    }

    /// At launch: the global shortcuts and the snippet expander start working.
    func start() {
        commands = buildCommands()
        syncHotKeys()
        expander.update()
        Task {
            apps = await offMain { AppIndex.scan() }
            appItems = apps.map(SearchCatalog.app)
        }
    }

    /// Flattened, in display order, for the arrow keys.
    var items: [SearchItem] { sections.flatMap(\.items) }

    var selectedItem: SearchItem? {
        let all = items
        return all.indices.contains(selection) ? all[selection] : all.first
    }

    /// Called each time the search opens: fresh query, apps and windows re-read in the
    /// background.
    func prepare() {
        mode = .all
        showsActions = false
        query = ""
        selection = 0
        files.cancel()
        commands = buildCommands()
        expander.update()
        recompute()
        Task {
            let apps = await offMain { AppIndex.scan() }
            guard apps != self.apps else { return }
            self.apps = apps
            self.appItems = apps.map(SearchCatalog.app)
            recompute(keepingSelection: true)
        }
        Task {
            openWindows = await offMain { WindowSwitcher.list() }
            if !query.isEmpty || mode == .windows { recompute(keepingSelection: true) }
        }
        Task {
            let wasLoaded = app.icons.isLoaded
            await app.icons.load()
            if !wasLoaded { recompute(keepingSelection: true) }
        }
        Task {
            let wasLoaded = EmojiModel.shared.isLoaded
            await EmojiModel.shared.load()
            if !wasLoaded { recompute(keepingSelection: true) }
        }
    }

    func setMode(_ mode: Mode) {
        guard mode != self.mode else { return }
        self.mode = mode
        showsActions = false
        if mode != .files { files.cancel() }
        recompute()
    }

    func move(_ offset: Int) {
        if showsActions {
            let count = actions(for: selectedItem).count
            guard count > 0 else { return }
            actionSelection = (actionSelection + offset + count) % count
            return
        }
        let count = items.count
        guard count > 0 else { return }
        selection = (selection + offset + count) % count
    }

    /// Runs an item and reports what the notch should do next.
    func run(_ item: SearchItem) -> SearchItem.Outcome {
        noteUsed(item.id)
        return item.action()
    }

    func run(_ action: SearchAction, of item: SearchItem) -> SearchItem.Outcome {
        noteUsed(item.id)
        let outcome = action.run()
        // The alias field and the shortcut recorder open inside the panel.
        if case .edit = outcome {} else { showsActions = false }
        return outcome
    }

    private func noteUsed(_ id: String) {
        var entry = usage[id] ?? Usage(count: 0, last: .now)
        entry.count += 1
        entry.last = .now
        usage[id] = entry
        if let data = try? JSONEncoder().encode(usage) { UserDefaults.standard.set(data, forKey: Self.usageKey) }
    }

    // MARK: ⌘K

    /// The item's own actions, then its alias and shortcut.
    func actions(for item: SearchItem?) -> [SearchAction] {
        guard let item else { return [] }
        var actions = [SearchAction(item.verb ?? String(localized: "Abrir"), symbol: "return", id: "primary", shortcut: "↩", run: item.action)]
        actions += item.actions
        guard item.isCustomizable else { return actions }
        let alias = library.aliases[item.id]
        actions.append(SearchAction(alias.map { String(localized: "Mudar apelido (\($0))") } ?? String(localized: "Dar um apelido"), symbol: "character.cursor.ibeam", id: "alias") {
            .edit(.alias(id: item.id, title: item.title))
        })
        let combo = library.hotKeys[item.id]
        actions.append(SearchAction(combo.map { String(localized: "Mudar atalho (\($0.display))") } ?? String(localized: "Dar um atalho global"), symbol: "command", id: "hotKey") {
            .edit(.hotKey(id: item.id, title: item.title))
        })
        if combo != nil {
            actions.append(SearchAction(String(localized: "Tirar o atalho"), symbol: "minus.circle", id: "removeHotKey") { [library] in
                library.setHotKey(nil, for: item.id, title: item.title)
                return .stay
            })
        }
        return actions
    }

    func beginEditing(_ editing: Editing) {
        recorderMessage = nil
        self.editing = editing
        if case .hotKey = editing { startRecording() }
    }

    func cancelEditing() {
        editing = nil
    }

    func saveAlias(_ alias: String) {
        guard case .alias(let id, _) = editing else { return }
        library.setAlias(alias, for: id)
        editing = nil
        showsActions = false
        recompute(keepingSelection: true)
    }

    /// The next key pressed with ⌘, ⌃ or ⌥ (or a function key) becomes the shortcut.
    /// ⌫ alone removes it; Esc leaves it as it was.
    private func startRecording() {
        stopRecording()
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, case .hotKey(let id, let title) = self.editing else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 {
                self.editing = nil
                return nil
            }
            if event.keyCode == 51, flags.isDisjoint(with: [.command, .control, .option]) {
                self.library.setHotKey(nil, for: id, title: title)
                self.editing = nil
                return nil
            }
            var modifiers: UInt32 = 0
            if flags.contains(.command) { modifiers |= KeyCombo.command }
            if flags.contains(.shift) { modifiers |= KeyCombo.shift }
            if flags.contains(.option) { modifiers |= KeyCombo.option }
            if flags.contains(.control) { modifiers |= KeyCombo.control }
            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            guard combo.isValid else {
                self.recorderMessage = String(localized: "Use junto ⌘, ⌃ ou ⌥")
                return nil
            }
            if combo == KeyCombo(keyCode: 0x31, modifiers: KeyCombo.option) || combo == KeyCombo(keyCode: 0x08, modifiers: KeyCombo.control | KeyCombo.option) {
                self.recorderMessage = String(localized: "Esse já abre o Cleen")
                return nil
            }
            self.library.setHotKey(combo, for: id, title: title)
            if self.hotKeys.taken.contains(id) {
                self.library.setHotKey(nil, for: id, title: title)
                self.recorderMessage = String(localized: "\(combo.display) já é de outro app")
                return nil
            }
            self.editing = nil
            self.showsActions = false
            return nil
        }
    }

    private func stopRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil
    }

    // MARK: Global shortcuts

    private func syncHotKeys() {
        hotKeys.sync(library.hotKeys) { [weak self] id in self?.runFromHotKey(id) }
    }

    /// A command's own shortcut: it runs as if picked in the search, without opening it.
    private func runFromHotKey(_ id: String) {
        guard let item = item(withID: id) else { return }
        PasteKeystroke.rememberTarget()
        noteUsed(id)
        let notch = app.notch
        switch item.action() {
        case .close, .stay, .edit:
            break
        case .closeAndPaste:
            PasteKeystroke.send()
        case .openTab(let tab):
            notch.openHeld(tab: tab)
        case .mode(let mode):
            notch.openSearch()
            setMode(mode)
        case .review(let review):
            notch.review(review)
        case .fill(let text):
            notch.openSearch()
            query = text
        }
    }

    /// The name to show for an item with an alias or shortcut, in Ajustes › Busca.
    func title(for id: String) -> String {
        item(withID: id)?.title ?? library.hotKeyTitles[id] ?? id
    }

    /// Any item that can carry a shortcut, found by its id even with the search closed.
    private func item(withID id: String) -> SearchItem? {
        if id.hasPrefix("app.") {
            let path = String(id.dropFirst("app.".count))
            let url = URL(filePath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return SearchCatalog.app(AppEntry(url: url, name: FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")))
        }
        if commands.isEmpty { commands = buildCommands() }
        return (commands + libraryItems(query: "")).first { $0.id == id }
    }

    // MARK: Results

    private func buildCommands() -> [SearchItem] {
        SearchCatalog.windows() + SearchCatalog.tools(live: app.live) + SearchCatalog.system(live: app.live) + SearchCatalog.tabs()
    }

    /// Quick links and snippets, as rows.
    private func libraryItems(query: String) -> [SearchItem] {
        library.quicklinks.compactMap { SearchCatalog.quicklink($0, query: "") } + library.snippets.map(SearchCatalog.snippet)
    }

    /// Today's events still ahead (or under way), soonest first.
    private var todaysEvents: [SearchItem] {
        app.agenda.events(on: .now).filter { !$0.isAllDay && $0.end > .now }.sorted { $0.start < $1.start }.map(SearchCatalog.event)
    }

    private func recompute(keepingSelection: Bool = false) {
        // Untouched (still on the first row), the selection follows what's now first:
        // an answer that arrives late (a currency rate) should be the one Return runs.
        let previous = keepingSelection && selection > 0 ? selectedItem?.id : nil
        sections = build()
        let all = items
        if let previous, let index = all.firstIndex(where: { $0.id == previous }) {
            selection = index
        } else {
            selection = previous == nil ? 0 : min(selection, max(0, all.count - 1))
        }
    }

    private func build() -> [SearchSection] {
        let text = query.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .files:
            files.search(text, limit: 30)
            return files.results.isEmpty ? [] : [SearchSection(title: String(localized: "Arquivos"), items: files.results.map(SearchCatalog.file))]
        case .windows:
            let windows = text.isEmpty ? openWindows.map(SearchCatalog.openWindow) : rank(openWindows.map(SearchCatalog.openWindow), for: text)
            return windows.isEmpty ? [] : [SearchSection(title: String(localized: "Janelas abertas"), items: windows)]
        case .all:
            break
        }
        guard !text.isEmpty else { return suggestions() }

        var sections: [SearchSection] = []
        if let (link, rest) = Quicklink.match(text, in: library.quicklinks), let item = SearchCatalog.quicklink(link, query: rest) {
            sections.append(SearchSection(title: String(localized: "Link rápido"), items: [item]))
        }
        let smart = smartResults(text)
        if !smart.isEmpty { sections.append(SearchSection(title: String(localized: "Calculadora"), items: smart)) }

        let ranked = rank(appItems + commands + libraryItems(query: text) + todaysEvents, for: text)
        if !ranked.isEmpty {
            sections.append(SearchSection(title: String(localized: "Resultados"), items: Array(ranked.prefix(12))))
        }
        if text.count >= 2 {
            let windows = rank(openWindows.map(SearchCatalog.openWindow), for: text).prefix(4)
            if !windows.isEmpty { sections.append(SearchSection(title: String(localized: "Janelas abertas"), items: Array(windows))) }
        }
        if text.count >= 3 {
            files.search(text, limit: 5)
            if !files.results.isEmpty { sections.append(SearchSection(title: String(localized: "Arquivos"), items: files.results.map(SearchCatalog.file))) }
        } else {
            files.cancel()
        }
        if text.count >= 2 {
            let clips = clipboardMatches(text)
            if !clips.isEmpty { sections.append(SearchSection(title: String(localized: "Área de transferência"), items: clips)) }
            let emoji = emojiMatches(text)
            if !emoji.isEmpty { sections.append(SearchSection(title: String(localized: "Emoji"), items: emoji)) }
            let icons = iconMatches(text)
            if !icons.isEmpty { sections.append(SearchSection(title: String(localized: "Ícones Lucide"), items: icons)) }
        }
        sections.append(SearchSection(title: String(localized: "Usar “\(text)” com…"), items: SearchCatalog.fallbacks(text, links: library.quicklinks)))
        return sections
    }

    /// Best first: an alias typed in full, then how well it matches, nudged by how often
    /// and how lately it ran.
    private func rank(_ candidates: [SearchItem], for text: String) -> [SearchItem] {
        let aliased = library.item(forAlias: text)
        let scored = candidates.compactMap { item -> (item: SearchItem, match: Double, total: Double)? in
            if item.id == aliased { return (item, 1, 10) }
            let keywords = item.keywords + (library.aliases[item.id].map { [$0] } ?? [])
            guard let score = FuzzyMatch.score(text, title: item.title, keywords: keywords) else { return nil }
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

    /// With nothing typed: today's next events, what you run most, then a few starting
    /// points.
    private func suggestions() -> [SearchSection] {
        var sections: [SearchSection] = []
        let events = todaysEvents.prefix(3)
        if !events.isEmpty { sections.append(SearchSection(title: String(localized: "Agenda de hoje"), items: Array(events))) }
        let everything = appItems + commands + libraryItems(query: "")
        let recent = usage
            .sorted { lhs, rhs in boost(lhs.key) > boost(rhs.key) }
            .compactMap { pair in everything.first { $0.id == pair.key } }
            .prefix(6)
        let starters = ["mode.windows", "mode.files", "window.leftHalf", "window.maximize", "tool.clipboard", "tool.emoji"]
            .compactMap { id in commands.first { $0.id == id } }
            .filter { item in !recent.contains { $0.id == item.id } }
        if !recent.isEmpty { sections.append(SearchSection(title: String(localized: "Recentes"), items: Array(recent))) }
        sections.append(SearchSection(title: String(localized: "Sugestões"), items: Array(starters.prefix(6 - min(recent.count, 3)))))
        return sections
    }

    // MARK: Calculator

    /// Arithmetic, conversions, time zones and dates: each answer is a row that copies
    /// itself on Return.
    private func smartResults(_ text: String) -> [SearchItem] {
        var items: [SearchItem] = []
        let separator = Locale.cleen.decimalSeparator?.first ?? "."
        if let value = Calculator.evaluate(text, decimalSeparator: separator) {
            items.append(answer("calc", value.formatted(.number.precision(.fractionLength(0...10)).locale(.cleen)), subtitle: text, symbol: "equal"))
        }
        if let conversion = UnitQuery.parse(text) {
            let converter = ConverterModel.shared
            if let result = conversion.result(rates: converter.rates) {
                let shown = ConverterNumber.format(result, isCurrency: conversion.isCurrency)
                let from = ConverterNumber.format(conversion.value, isCurrency: conversion.isCurrency)
                var subtitle = "\(from) \(conversion.from.symbol) · \(conversion.from.name) → \(conversion.to.name)"
                if conversion.isCurrency, let day = converter.rates?.publishedOn {
                    subtitle = String(localized: "\(from) \(conversion.from.symbol) · cotação de \(day.formatted(.dateTime.day().month(.abbreviated).locale(.cleen)))")
                }
                items.append(answer("convert", "\(shown) \(conversion.to.symbol)", subtitle: subtitle, symbol: conversion.isCurrency ? "dollarsign.arrow.circlepath" : "arrow.left.arrow.right", copy: shown))
            } else if conversion.isCurrency {
                // The rates come in a moment; the row appears when they do.
                converter.refreshRatesIfNeeded()
                Task {
                    for _ in 0..<20 where converter.rates == nil || converter.ratesState == .loading {
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                    if self.query == text { self.recompute(keepingSelection: true) }
                }
            }
        }
        if let time = TimeZoneQuery.parse(text) {
            items.append(timeAnswer(time))
        }
        if let date = DateQuery.parse(text) {
            items.append(dateAnswer(date))
        }
        return items
    }

    private func answer(_ id: String, _ title: String, subtitle: String?, symbol: String, copy: String? = nil) -> SearchItem {
        let text = copy ?? title
        return SearchItem(id: id, title: title, subtitle: subtitle, icon: .symbol(symbol, ToolPalette.orange), kind: String(localized: "Copiar"), verb: String(localized: "Copiar"),
                          actions: [SearchAction(String(localized: "Colar"), symbol: "doc.on.clipboard", shortcut: "⌘↩") {
                              SearchPaste.put(text)
                              return .closeAndPaste
                          }]) { [live = app.live] in
            SearchPaste.put(text)
            live.copied(text)
            return .close
        }
    }

    private func timeAnswer(_ time: TimeZoneQuery) -> SearchItem {
        let clock = Date.FormatStyle.dateTime.hour().minute().locale(.cleen)
        var clockThere = clock
        clockThere.timeZone = time.zone
        let there = time.date.formatted(clockThere)
        let here = time.date.formatted(clock)
        // The calendar day on each side, as a plain number (20261026) to compare.
        func day(in zone: TimeZone) -> Int {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let parts = calendar.dateComponents([.year, .month, .day], from: time.date)
            return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
        }
        let difference = day(in: time.zone) - day(in: .current)
        if time.isFromThere {
            let note = difference > 0 ? String(localized: " · dia anterior aqui") : difference < 0 ? String(localized: " · dia seguinte aqui") : ""
            return answer("time", String(localized: "\(here) aqui"), subtitle: String(localized: "\(there) em \(time.place)") + note, symbol: "globe", copy: here)
        }
        let isNow = abs(time.date.timeIntervalSinceNow) < 60
        let note = difference > 0 ? String(localized: " · dia seguinte lá") : difference < 0 ? String(localized: " · dia anterior lá") : ""
        let subtitle = (isNow ? String(localized: "Agora") : String(localized: "\(here) aqui")) + note
        return answer("time", String(localized: "\(there) em \(time.place)"), subtitle: subtitle, symbol: "globe", copy: there)
    }

    private func dateAnswer(_ date: DateQuery) -> SearchItem {
        let long = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide).year().locale(.cleen)
        let today = Calendar.current.startOfDay(for: .now)
        switch date.answer {
        case .date(let day):
            let days = Calendar.current.dateComponents([.day], from: today, to: day).day ?? 0
            let distance = switch days {
            case 0: String(localized: "hoje")
            case 1: String(localized: "amanhã")
            case -1: String(localized: "ontem")
            case 2...: String(localized: "daqui a \(days) dias")
            default: String(localized: "há \(-days) dias")
            }
            return answer("date", day.formatted(long), subtitle: distance, symbol: "calendar", copy: day.formatted(.dateTime.day().month(.twoDigits).year().locale(.cleen)))
        case .days(let days, let until):
            let title = abs(days) == 1 ? String(localized: "1 dia") : String(localized: "\(abs(days)) dias")
            let subtitle = days >= 0 ? String(localized: "até \(until.formatted(long))") : String(localized: "desde \(until.formatted(long))")
            return answer("days", title, subtitle: subtitle, symbol: "calendar", copy: "\(abs(days))")
        }
    }

    // MARK: Other sources

    private func clipboardMatches(_ text: String) -> [SearchItem] {
        app.clipboard.log.entries
            .filter { ($0.kind == .text || $0.kind == .link) && FuzzyMatch.fold($0.text ?? "").contains(FuzzyMatch.fold(text)) }
            .prefix(3)
            .map { entry in
                let line = (entry.text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                return SearchItem(id: "clip.\(entry.id)", title: line, subtitle: entry.sourceName, icon: .symbol(entry.kind == .link ? "link" : "text.alignleft", ToolPalette.indigo),
                                  kind: String(localized: "Colar"), verb: String(localized: "Colar"),
                                  actions: [SearchAction(String(localized: "Copiar"), symbol: "doc.on.doc", shortcut: "⌘C") { [clipboard = app.clipboard] in
                                      clipboard.copy(entry)
                                      return .close
                                  }]) { [clipboard = app.clipboard] in
                    clipboard.copy(entry)
                    return .closeAndPaste
                }
            }
    }

    private func iconMatches(_ text: String) -> [SearchItem] {
        app.icons.search(text, limit: 4).map { icon in
            SearchItem(id: "lucide.\(icon.name)", title: icon.name, icon: .lucide(icon), kind: String(localized: "Copiar SVG"), verb: String(localized: "Copiar SVG")) { [icons = app.icons, live = app.live] in
                Task {
                    if await icons.copySVG(icon) { live.copied("\(icon.name).svg") }
                }
                return .close
            }
        }
    }

    private func emojiMatches(_ text: String) -> [SearchItem] {
        EmojiModel.shared.matches(text, limit: 4).map { item in
            SearchItem(id: "emoji.\(item.emoji)", title: item.name, icon: .emoji(item.emoji), kind: String(localized: "Colar"), verb: String(localized: "Colar"),
                       actions: [SearchCatalog.copyAction { item.emoji }]) {
                EmojiModel.shared.noteUsed(item)
                SearchPaste.put(item.emoji)
                return .closeAndPaste
            }
        }
    }
}
