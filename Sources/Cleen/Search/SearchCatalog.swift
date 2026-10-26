import AppKit
import CleenKit
import SwiftUI

/// The search's fixed commands (window placement, Cleen's tools and tabs, the Mac's own
/// commands) and how each kind of result is turned into a row with its ⌘K actions.
enum SearchCatalog {
    static func windows() -> [SearchItem] {
        let window = String(localized: "Janela")
        func item(_ layout: WindowLayout, _ title: String, _ symbol: String, _ keywords: [String]) -> SearchItem {
            SearchItem(id: "window.\(layout.rawValue)", title: title, icon: .symbol(symbol, ToolPalette.blue), keywords: keywords, kind: window,
                       verb: String(localized: "Ajustar janela"), isCustomizable: true) {
                WindowManager.apply(layout)
                return .close
            }
        }
        return [
            item(.leftHalf, String(localized: "Metade esquerda"), "rectangle.lefthalf.filled", ["left half"]),
            item(.rightHalf, String(localized: "Metade direita"), "rectangle.righthalf.filled", ["right half"]),
            item(.topHalf, String(localized: "Metade de cima"), "rectangle.tophalf.filled", ["top half"]),
            item(.bottomHalf, String(localized: "Metade de baixo"), "rectangle.bottomhalf.filled", ["bottom half"]),
            item(.maximize, String(localized: "Maximizar"), "rectangle.inset.filled", ["maximize", "fill", "tela cheia"]),
            item(.almostMaximize, String(localized: "Quase maximizar"), "rectangle.center.inset.filled", ["almost maximize"]),
            item(.center, String(localized: "Centralizar"), "rectangle.center.inset.filled", ["center"]),
            item(.topLeft, String(localized: "Canto superior esquerdo"), "rectangle.inset.topleft.filled", ["top left quarter"]),
            item(.topRight, String(localized: "Canto superior direito"), "rectangle.inset.topright.filled", ["top right quarter"]),
            item(.bottomLeft, String(localized: "Canto inferior esquerdo"), "rectangle.inset.bottomleft.filled", ["bottom left quarter"]),
            item(.bottomRight, String(localized: "Canto inferior direito"), "rectangle.inset.bottomright.filled", ["bottom right quarter"]),
            item(.firstThird, String(localized: "Primeiro terço"), "rectangle.leadingthird.inset.filled", ["first third"]),
            item(.centerThird, String(localized: "Terço do meio"), "rectangle.center.inset.filled", ["center third"]),
            item(.lastThird, String(localized: "Último terço"), "rectangle.trailingthird.inset.filled", ["last third"]),
            item(.firstTwoThirds, String(localized: "Dois terços à esquerda"), "rectangle.leadinghalf.inset.filled", ["first two thirds"]),
            item(.lastTwoThirds, String(localized: "Dois terços à direita"), "rectangle.trailinghalf.inset.filled", ["last two thirds"]),
            SearchItem(id: "window.nextDisplay", title: String(localized: "Próxima tela"), icon: .symbol("rectangle.on.rectangle", ToolPalette.blue),
                       keywords: ["next display", "move to next screen", "monitor"], kind: window, verb: String(localized: "Ajustar janela"), isCustomizable: true) {
                WindowManager.moveToNextScreen()
                return .close
            },
            SearchItem(id: "window.restore", title: String(localized: "Restaurar tamanho"), icon: .symbol("arrow.uturn.backward", ToolPalette.blue),
                       keywords: ["restore"], kind: window, verb: String(localized: "Ajustar janela"), isCustomizable: true) {
                WindowManager.restore()
                return .close
            },
        ]
    }

    static func tools(live: LiveActivityCenter) -> [SearchItem] {
        let command = String(localized: "Comando")
        func lorem(_ id: String, _ title: String, _ make: @escaping @MainActor () -> String) -> SearchItem {
            SearchItem(id: "lorem.\(id)", title: title, icon: .symbol("text.alignleft", ToolPalette.gray), keywords: ["lorem ipsum", "placeholder", "texto"], kind: command,
                       verb: String(localized: "Colar"), actions: [copyAction { make() }], isCustomizable: true) {
                SearchPaste.put(make())
                return .closeAndPaste
            }
        }
        func tool(_ id: String, _ title: String, _ symbol: String, _ color: Color, _ keywords: [String], subtitle: String? = nil, run: @escaping @MainActor () -> SearchItem.Outcome) -> SearchItem {
            SearchItem(id: id, title: title, subtitle: subtitle, icon: .symbol(symbol, color), keywords: keywords, kind: command, verb: String(localized: "Executar"), isCustomizable: true, action: run)
        }
        return [
            tool("tool.colorPicker", String(localized: "Conta-gotas"), "eyedropper", ToolPalette.pink, ["color picker", "cor", "pick color", "hex"], subtitle: String(localized: "Pega uma cor da tela e copia o hex")) {
                // After the notch is out of the way, so it can be sampled too.
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    ColorPick.pick { hex in live.copied(hex, color: ColorPick.color(hex: hex)) }
                }
                return .close
            },
            tool("tool.confetti", String(localized: "Confete"), "party.popper", ToolPalette.orange, ["confetti", "celebrar", "festa"]) {
                Confetti.fire()
                return .close
            },
            lorem("paragraph", String(localized: "Lorem ipsum: 1 parágrafo")) { LoremIpsum.paragraphs(1) },
            lorem("paragraphs", String(localized: "Lorem ipsum: 3 parágrafos")) { LoremIpsum.paragraphs(3) },
            lorem("sentence", String(localized: "Lorem ipsum: 1 frase")) { LoremIpsum.sentences(1) },
            lorem("words", String(localized: "Lorem ipsum: 10 palavras")) { LoremIpsum.words(10) },
            tool("tool.emoji", String(localized: "Buscar emoji"), "face.smiling", ToolPalette.yellow, ["emoji", "search emoji"]) { .openTab(.emoji) },
            tool("tool.clipboard", String(localized: "Histórico da área de transferência"), "doc.on.clipboard", ToolPalette.indigo, ["clipboard history", "copiados"]) { .openTab(.clipboard) },
            tool("tool.icons", String(localized: "Buscar ícones Lucide"), "square.grid.3x3.square", ToolPalette.teal, ["lucide", "icons", "ícones", "svg"]) { .openTab(.icons) },
            tool("mode.files", String(localized: "Buscar arquivos"), "doc.text.magnifyingglass", ToolPalette.blue, ["search files", "find file", "arquivo", "spotlight"]) { .mode(.files) },
            tool("mode.windows", String(localized: "Trocar de janela"), "macwindow.on.rectangle", ToolPalette.blue, ["switch windows", "janelas abertas", "window switcher"]) { .mode(.windows) },
        ]
    }

    /// The Mac's own commands. The ones that close apps or end the session ask first.
    static func system(live: LiveActivityCenter) -> [SearchItem] {
        let command = String(localized: "Sistema")
        func item(_ id: String, _ title: String, _ symbol: String, _ keywords: [String], run: @escaping @MainActor () -> SearchItem.Outcome) -> SearchItem {
            SearchItem(id: "system.\(id)", title: title, icon: .symbol(symbol, ToolPalette.gray), keywords: keywords, kind: command, verb: String(localized: "Executar"), isCustomizable: true, action: run)
        }
        func confirmPower(_ power: SystemCommands.Power, _ title: String, _ consequence: String) -> SearchItem.Outcome {
            let apps = SystemCommands.quittableApps
            return .review(DeletionReview(
                title: title,
                items: apps.map { DeletionReview.Item(id: "\($0.processIdentifier)", name: $0.localizedName ?? "", detail: String(localized: "Vai fechar"), url: $0.bundleURL) },
                outcome: .action(consequence),
                confirm: { SystemCommands.power(power) }
            ))
        }
        return [
            item("lock", String(localized: "Bloquear tela"), "lock", ["lock screen"]) {
                SystemCommands.lockScreen()
                return .close
            },
            item("sleep", String(localized: "Repouso"), "moon", ["sleep", "dormir"]) {
                SystemCommands.sleep()
                return .close
            },
            item("screenSaver", String(localized: "Proteção de tela"), "sparkles.tv", ["screen saver", "protetor de tela"]) {
                SystemCommands.screenSaver()
                return .close
            },
            item("restart", String(localized: "Reiniciar"), "arrow.clockwise", ["restart", "reboot"]) {
                confirmPower(.restart, String(localized: "Reiniciar o Mac?"), String(localized: "Os apps abertos são fechados; os que têm algo sem salvar ainda perguntam antes."))
            },
            item("shutDown", String(localized: "Desligar"), "power", ["shut down", "shutdown", "desligar o mac"]) {
                confirmPower(.shutDown, String(localized: "Desligar o Mac?"), String(localized: "Os apps abertos são fechados; os que têm algo sem salvar ainda perguntam antes."))
            },
            item("logOut", String(localized: "Encerrar sessão"), "rectangle.portrait.and.arrow.right", ["log out", "logout", "sair da conta"]) {
                confirmPower(.logOut, String(localized: "Encerrar a sessão?"), String(localized: "Os apps abertos são fechados e o Mac volta para a tela de login."))
            },
            item("darkMode", String(localized: "Alternar modo escuro"), "circle.lefthalf.filled", ["dark mode", "light mode", "tema", "aparência", "modo claro"]) {
                SystemCommands.toggleDarkMode()
                return .close
            },
            item("hideAll", String(localized: "Ocultar todos os apps"), "eye.slash", ["hide all apps", "mostrar mesa", "desktop"]) {
                SystemCommands.hideAll()
                return .close
            },
            item("quitAll", String(localized: "Sair de todos os apps"), "xmark.square", ["quit all apps", "fechar todos os apps", "fechar tudo"]) {
                let apps = SystemCommands.quittableApps
                guard !apps.isEmpty else {
                    live.notice(String(localized: "Apps"), detail: String(localized: "Nenhum aberto"), symbol: "checkmark")
                    return .close
                }
                return .review(DeletionReview(
                    title: apps.count == 1 ? String(localized: "Fechar 1 app?") : String(localized: "Fechar \(apps.count) apps?"),
                    items: apps.map { DeletionReview.Item(id: "\($0.processIdentifier)", name: $0.localizedName ?? "", url: $0.bundleURL) },
                    outcome: .action(String(localized: "Cada app recebe um ⌘Q: os que têm algo sem salvar perguntam antes de fechar.")),
                    confirm: { SystemCommands.quitAll() }
                ))
            },
            item("ejectAll", String(localized: "Ejetar todos os discos"), "eject", ["eject all disks", "ejetar", "pendrive", "hd externo"]) {
                let volumes = SystemCommands.ejectableVolumes
                guard !volumes.isEmpty else {
                    live.notice(String(localized: "Discos"), detail: String(localized: "Nenhum para ejetar"), symbol: "eject")
                    return .close
                }
                SystemCommands.ejectAll { ejected, failed in
                    if failed > 0 {
                        live.notice(String(localized: "Discos"), detail: failed == 1 ? String(localized: "1 em uso") : String(localized: "\(failed) em uso"), symbol: "exclamationmark.triangle")
                    } else {
                        live.notice(String(localized: "Discos"), detail: ejected == 1 ? String(localized: "1 ejetado") : String(localized: "\(ejected) ejetados"), symbol: "eject")
                    }
                }
                return .close
            },
            item("emptyTrash", String(localized: "Esvaziar o Lixo"), "trash", ["empty trash", "lixeira", "lixo"]) {
                let items = SystemCommands.trashItems
                let rows = items.isEmpty
                    ? [DeletionReview.Item(id: "trash", name: String(localized: "Tudo o que está no Lixo"), symbol: "trash")]
                    : items.map { url in DeletionReview.Item(url: url, size: Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0), detail: String(localized: "Lixo")) }
                return .review(DeletionReview(
                    title: String(localized: "Esvaziar o Lixo?"),
                    items: rows,
                    outcome: .delete,
                    confirm: { SystemCommands.emptyTrash() }
                ))
            },
        ]
    }

    /// Every tab of the notch, to jump straight to it.
    static func tabs() -> [SearchItem] {
        NotchTab.allCases.map { tab in
            SearchItem(id: "tab.\(tab.rawValue)", title: tab.settingsTitle, icon: .symbol(tab.symbol, NotchStyle.secondary),
                       keywords: [tab.rawValue], kind: String(localized: "Cleen"), verb: String(localized: "Abrir"), isCustomizable: true) { .openTab(tab) }
        }
    }

    // MARK: Results

    static func app(_ entry: AppEntry) -> SearchItem {
        let running = { NSRunningApplication.runningApplications(withBundleIdentifier: Bundle(url: entry.url)?.bundleIdentifier ?? "").first }
        var actions = [
            revealAction(entry.url),
            SearchAction(String(localized: "Copiar caminho"), symbol: "doc.on.doc", shortcut: "⌘⇧C") {
                SearchPaste.put(entry.url.path(percentEncoded: false))
                return .close
            },
        ]
        if let app = running() {
            actions += [
                SearchAction(String(localized: "Ocultar"), symbol: "eye.slash", shortcut: "⌘H") {
                    app.hide()
                    return .close
                },
                SearchAction(String(localized: "Sair"), symbol: "xmark.circle", shortcut: "⌘Q") {
                    app.terminate()
                    return .close
                },
                SearchAction(String(localized: "Forçar saída"), symbol: "exclamationmark.octagon", isDestructive: true) {
                    .review(DeletionReview(
                        title: String(localized: "Forçar a saída do \(entry.name)?"),
                        items: [DeletionReview.Item(id: entry.id, name: entry.name, url: entry.url)],
                        outcome: .action(String(localized: "O app fecha na hora, sem salvar o que estiver aberto nele.")),
                        confirm: { app.forceTerminate() }
                    ))
                },
            ]
        }
        return SearchItem(id: "app.\(entry.id)", title: entry.name, icon: .app(entry.url), kind: String(localized: "App"), verb: String(localized: "Abrir"),
                          actions: actions, isCustomizable: true) {
            NSWorkspace.shared.openApplication(at: entry.url, configuration: .init())
            if let app = running() { PasteKeystroke.target = app }
            return .close
        }
    }

    static func openWindow(_ window: OpenWindow) -> SearchItem {
        SearchItem(id: "openWindow.\(window.id)", title: window.title, subtitle: window.title == window.appName ? nil : window.appName,
                   icon: window.appURL.map { .app($0) } ?? .symbol("macwindow", ToolPalette.blue), keywords: [window.appName],
                   kind: window.isMinimized ? String(localized: "Minimizada") : String(localized: "Janela aberta"), verb: String(localized: "Ir para a janela"),
                   actions: [
                       SearchAction(String(localized: "Fechar janela"), symbol: "xmark", shortcut: "⌘W") {
                           WindowSwitcher.close(window)
                           return .close
                       },
                       SearchAction(String(localized: "Sair do \(window.appName)"), symbol: "xmark.circle", shortcut: "⌘Q") {
                           NSRunningApplication(processIdentifier: window.pid)?.terminate()
                           return .close
                       },
                   ]) {
            WindowSwitcher.focus(window)
            return .close
        }
    }

    static func file(_ result: FileSearch.Result) -> SearchItem {
        let url = result.url
        let folder = Paths.abbreviate(url.deletingLastPathComponent())
        var actions = [revealAction(url)]
        // Up to four other apps that open this kind of file, the default one first.
        let apps = NSWorkspace.shared.urlsForApplications(toOpen: url).prefix(5)
        for app in apps.dropFirst() {
            let name = FileManager.default.displayName(atPath: app.path(percentEncoded: false)).replacingOccurrences(of: ".app", with: "")
            actions.append(SearchAction(String(localized: "Abrir com \(name)"), symbol: "arrow.up.forward.app", id: "openWith.\(app.path())") {
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                return .close
            })
        }
        actions += [
            SearchAction(String(localized: "Copiar caminho"), symbol: "doc.on.doc", shortcut: "⌘⇧C") {
                SearchPaste.put(url.path(percentEncoded: false))
                return .close
            },
            SearchAction(String(localized: "Copiar arquivo"), symbol: "doc.on.clipboard", shortcut: "⌘C") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
                return .close
            },
            SearchAction(String(localized: "Mover para o Lixo"), symbol: "trash", shortcut: "⌘⌫", isDestructive: true) {
                .review(DeletionReview(
                    title: DeletionReview.title(count: 1, outcome: .trash),
                    items: [DeletionReview.Item(url: url, size: nil)],
                    outcome: .trash,
                    confirm: { NSWorkspace.shared.recycle([url]) }
                ))
            },
        ]
        return SearchItem(id: "file.\(result.id)", title: result.name, subtitle: folder, icon: .file(url), kind: String(localized: "Arquivo"),
                          verb: String(localized: "Abrir"), actions: actions) {
            NSWorkspace.shared.open(url)
            return .close
        }
    }

    /// A quick link with what's typed after its keyword. One that needs a query and has
    /// none yet fills the field with its keyword on Return.
    static func quicklink(_ link: Quicklink, query: String) -> SearchItem? {
        let base = SearchItem(id: "quicklink.\(link.id)", title: link.name, icon: .symbol("link", ToolPalette.teal), keywords: [link.keyword],
                              kind: String(localized: "Link rápido"), verb: String(localized: "Abrir"), isCustomizable: true) { .stay }
        guard let url = link.url(for: query) else {
            guard link.takesQuery, !link.keyword.isEmpty else { return nil }
            return SearchItem(id: base.id, title: link.name, subtitle: String(localized: "\(link.keyword) + o que buscar"), icon: base.icon, keywords: base.keywords,
                              kind: base.kind, verb: String(localized: "Digitar"), isCustomizable: true) { .fill(link.keyword + " ") }
        }
        let title = query.isEmpty || !link.takesQuery ? link.name : String(localized: "\(link.name): \(query)")
        return SearchItem(id: base.id, title: title, subtitle: url.host(), icon: base.icon, keywords: base.keywords, kind: base.kind, verb: base.verb,
                          actions: [copyAction { url.absoluteString }], isCustomizable: true) {
            NSWorkspace.shared.open(url)
            return .close
        }
    }

    static func snippet(_ snippet: Snippet) -> SearchItem {
        let preview = snippet.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return SearchItem(id: "snippet.\(snippet.id)", title: snippet.name, subtitle: snippet.keyword.isEmpty ? preview : snippet.keyword,
                          icon: .symbol("text.quote", ToolPalette.purple), keywords: [snippet.keyword, preview], kind: String(localized: "Snippet"),
                          verb: String(localized: "Colar"), actions: [copyAction { snippet.expanded(clipboard: NSPasteboard.general.string(forType: .string)).text }],
                          isCustomizable: true) {
            SearchPaste.put(snippet.expanded(clipboard: NSPasteboard.general.string(forType: .string)).text)
            return .closeAndPaste
        }
    }

    static func event(_ event: AgendaEvent) -> SearchItem {
        let now = Date.now
        let subtitle = event.start <= now && event.end > now ? String(localized: "Agora · \(event.timeText)") : event.timeText
        var actions: [SearchAction] = [
            SearchAction(String(localized: "Abrir no Calendário"), symbol: "calendar", shortcut: "⌘↩") {
                AgendaModel.openCalendar()
                return .close
            },
        ]
        if let link = event.meetingURL {
            actions.append(copyAction(String(localized: "Copiar link da reunião")) { link.absoluteString })
        }
        return SearchItem(id: "event.\(event.id)", title: event.title, subtitle: subtitle, icon: .symbol(event.meetingURL == nil ? "calendar" : "video", Color(nsColor: event.color)),
                          kind: event.meetingURL == nil ? String(localized: "Evento") : String(localized: "Reunião"),
                          verb: event.meetingURL == nil ? String(localized: "Abrir") : String(localized: "Entrar na reunião"), actions: actions) {
            if let link = event.meetingURL { NSWorkspace.shared.open(link) } else { AgendaModel.openCalendar() }
            return .close
        }
    }

    /// "Buscar 'x' no Google" and the rest of the quick links, under everything else.
    static func fallbacks(_ text: String, links: [Quicklink]) -> [SearchItem] {
        var items: [SearchItem] = []
        if let address = WebAddress.url(from: text) {
            items.append(SearchItem(id: "web.open", title: String(localized: "Abrir \(address.host() ?? text)"), subtitle: address.absoluteString,
                                    icon: .symbol("safari", ToolPalette.blue), kind: String(localized: "Site"), verb: String(localized: "Abrir"),
                                    actions: [copyAction { address.absoluteString }]) {
                NSWorkspace.shared.open(address)
                return .close
            })
        }
        for link in links.filter(\.takesQuery).prefix(3) {
            guard let url = link.url(for: text) else { continue }
            items.append(SearchItem(id: "fallback.\(link.id)", title: String(localized: "Buscar “\(text)” no \(link.name)"), icon: .symbol("magnifyingglass", ToolPalette.teal),
                                    kind: String(localized: "Web"), verb: String(localized: "Buscar"), actions: [copyAction { url.absoluteString }]) {
                NSWorkspace.shared.open(url)
                return .close
            })
        }
        items.append(SearchItem(id: "fallback.files", title: String(localized: "Buscar arquivos com “\(text)”"), icon: .symbol("doc.text.magnifyingglass", ToolPalette.blue),
                                kind: String(localized: "Arquivos"), verb: String(localized: "Buscar")) { .mode(.files) })
        return items
    }

    // MARK: Shared actions

    static func revealAction(_ url: URL) -> SearchAction {
        SearchAction(String(localized: "Mostrar no Finder"), symbol: "folder", shortcut: "⌘↩") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            PasteKeystroke.target = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
            return .close
        }
    }

    static func copyAction(_ title: String = String(localized: "Copiar"), _ text: @escaping @MainActor () -> String) -> SearchAction {
        SearchAction(title, symbol: "doc.on.doc", shortcut: "⌘C") {
            SearchPaste.put(text())
            return .close
        }
    }
}

/// Puts text on the clipboard for a paste that happens once the search has closed.
enum SearchPaste {
    static func put(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
