import Foundation

/// A step before something that can't be taken back (restarting, shutting down, quitting
/// every app, forcing an app to quit): the notch grows and lists what it touches, with
/// Cancelar and Confirmar. Apagar and Mover para o Lixo don't come through here, they
/// act on the click. `NotchState.deletionReview` holds the one on screen.
struct DeletionReview: Identifiable {
    struct Item: Identifiable {
        let id: String
        let name: String
        /// What it is or what happens to it: "Vai fechar".
        var detail: String?
        /// An app or a file on disk: its Finder icon is shown.
        var url: URL?
        /// Otherwise an SF Symbol.
        var symbol: String = "doc"
    }

    enum Outcome {
        /// Hard to take back: the text says what happens.
        case action(String)
    }

    let id = UUID()
    /// "Reiniciar o Mac?"
    let title: String
    let items: [Item]
    let outcome: Outcome
    let confirm: () -> Void

    /// What happens, said plainly under the title.
    var consequence: String {
        switch outcome {
        case .action(let text): text
        }
    }
}
