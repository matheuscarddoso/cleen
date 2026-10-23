import AppKit
import CleenKit
import SwiftUI

/// The fixed commands: window placement, Cleen's own tools and tabs, and a few things
/// from the person's Raycast (color picker, confetti, lorem ipsum).
enum SearchCatalog {
    static func windows() -> [SearchItem] {
        let window = String(localized: "Janela")
        func item(_ layout: WindowLayout, _ title: String, _ symbol: String, _ keywords: [String]) -> SearchItem {
            SearchItem(id: "window.\(layout.rawValue)", title: title, icon: .symbol(symbol, ToolPalette.blue), keywords: keywords, kind: window) {
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
                       keywords: ["next display", "move to next screen", "monitor"], kind: window) {
                WindowManager.moveToNextScreen()
                return .close
            },
            SearchItem(id: "window.restore", title: String(localized: "Restaurar tamanho"), icon: .symbol("arrow.uturn.backward", ToolPalette.blue),
                       keywords: ["restore"], kind: window) {
                WindowManager.restore()
                return .close
            },
        ]
    }

    static func tools(live: LiveActivityCenter) -> [SearchItem] {
        let command = String(localized: "Comando")
        func lorem(_ id: String, _ title: String, _ make: @escaping @MainActor () -> String) -> SearchItem {
            SearchItem(id: "lorem.\(id)", title: title, icon: .symbol("text.alignleft", ToolPalette.gray), keywords: ["lorem ipsum", "placeholder", "texto"], kind: command) {
                SearchPaste.put(make())
                return .closeAndPaste
            }
        }
        return [
            SearchItem(id: "tool.colorPicker", title: String(localized: "Conta-gotas"), subtitle: String(localized: "Pega uma cor da tela e copia o hex"),
                       icon: .symbol("eyedropper", ToolPalette.pink), keywords: ["color picker", "cor", "pick color", "hex"], kind: command) {
                // After the notch is out of the way, so it can be sampled too.
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    ColorPick.pick { hex in live.copied(hex, color: ColorPick.color(hex: hex)) }
                }
                return .close
            },
            SearchItem(id: "tool.confetti", title: String(localized: "Confete"), icon: .symbol("party.popper", ToolPalette.orange),
                       keywords: ["confetti", "celebrar", "festa"], kind: command) {
                Confetti.fire()
                return .close
            },
            lorem("paragraph", String(localized: "Lorem ipsum: 1 parágrafo")) { LoremIpsum.paragraphs(1) },
            lorem("paragraphs", String(localized: "Lorem ipsum: 3 parágrafos")) { LoremIpsum.paragraphs(3) },
            lorem("sentence", String(localized: "Lorem ipsum: 1 frase")) { LoremIpsum.sentences(1) },
            lorem("words", String(localized: "Lorem ipsum: 10 palavras")) { LoremIpsum.words(10) },
            SearchItem(id: "tool.emoji", title: String(localized: "Buscar emoji"), icon: .symbol("face.smiling", ToolPalette.yellow),
                       keywords: ["emoji", "search emoji"], kind: command) { .openTab(.emoji) },
            SearchItem(id: "tool.clipboard", title: String(localized: "Histórico da área de transferência"), icon: .symbol("doc.on.clipboard", ToolPalette.indigo),
                       keywords: ["clipboard history", "copiados"], kind: command) { .openTab(.clipboard) },
            SearchItem(id: "tool.icons", title: String(localized: "Buscar ícones Lucide"), icon: .symbol("square.grid.3x3.square", ToolPalette.teal),
                       keywords: ["lucide", "icons", "ícones", "svg"], kind: command) { .openTab(.icons) },
            SearchItem(id: "system.lock", title: String(localized: "Bloquear tela"), icon: .symbol("lock", ToolPalette.gray),
                       keywords: ["lock screen"], kind: command) {
                SystemCommands.lockScreen()
                return .close
            },
            SearchItem(id: "system.sleep", title: String(localized: "Repouso"), icon: .symbol("moon", ToolPalette.gray),
                       keywords: ["sleep", "dormir"], kind: command) {
                SystemCommands.sleep()
                return .close
            },
        ]
    }

    /// Every tab of the notch, to jump straight to it.
    static func tabs() -> [SearchItem] {
        NotchTab.allCases.map { tab in
            SearchItem(id: "tab.\(tab.rawValue)", title: tab.settingsTitle, icon: .symbol(tab.symbol, NotchStyle.secondary),
                       keywords: [tab.rawValue], kind: String(localized: "Cleen")) { .openTab(tab) }
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

enum SystemCommands {
    /// The same as ⌃⌘Q.
    static func lockScreen() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyQ: CGKeyCode = 12
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyQ, keyDown: down)
            event?.flags = [.maskCommand, .maskControl]
            event?.post(tap: .cghidEventTap)
        }
    }

    static func sleep() {
        Task.detached { _ = try? await Shell.run("/usr/bin/pmset", ["sleepnow"]) }
    }
}
