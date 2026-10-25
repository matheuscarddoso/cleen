import CleenKit
import Foundation

/// Everything that deletes asks first: the notch grows and lists what's about to go,
/// with Cancelar and Confirmar. A review carries that list and the work to do once it's
/// confirmed; `NotchState.deletionReview` holds the one on screen.
struct DeletionReview: Identifiable {
    struct Item: Identifiable {
        let id: String
        let name: String
        /// Where it is or what it belongs to: "Caches do Xcode", "~/Downloads".
        var detail: String?
        var size: Int64?
        /// A file on disk: its Finder icon is shown.
        var url: URL?
        /// Otherwise an SF Symbol.
        var symbol: String = "doc"
    }

    enum Outcome {
        /// Goes to the Lixo: one drag brings it back.
        case trash
        /// Gone for good.
        case delete
        /// Some of each.
        case mixed
    }

    let id = UUID()
    /// "Mover 12 itens para o Lixo?"
    let title: String
    let items: [Item]
    let outcome: Outcome
    let confirm: () -> Void

    var totalSize: Int64? {
        let sizes = items.compactMap(\.size)
        return sizes.isEmpty ? nil : sizes.reduce(0, +)
    }

    /// What happens to it, said plainly under the title.
    var consequence: String {
        switch outcome {
        case .trash: String(localized: "Vai para o Lixo: dá para recuperar de lá.")
        case .delete: String(localized: "É apagado de vez, sem passar pelo Lixo.")
        case .mixed: String(localized: "Parte vai para o Lixo e parte é apagada de vez.")
        }
    }

    init(title: String, items: [Item], outcome: Outcome, confirm: @escaping () -> Void) {
        self.title = title
        self.items = items
        self.outcome = outcome
        self.confirm = confirm
    }

    /// "Mover 3 itens para o Lixo?", "Apagar 1 item?"
    static func title(count: Int, outcome: Outcome) -> String {
        switch outcome {
        case .trash: count == 1 ? String(localized: "Mover 1 item para o Lixo?") : String(localized: "Mover \(count) itens para o Lixo?")
        case .delete, .mixed: count == 1 ? String(localized: "Apagar 1 item?") : String(localized: "Apagar \(count) itens?")
        }
    }
}

extension DeletionReview.Item {
    /// A file or folder: named after itself, its folder as the detail.
    init(url: URL, size: Int64?, detail: String? = nil) {
        self.init(id: url.path(percentEncoded: false), name: url.lastPathComponent, detail: detail ?? Paths.abbreviate(url.deletingLastPathComponent()), size: size, url: url)
    }
}
