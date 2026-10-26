import CleenKit
import Foundation

/// The global shortcuts given to commands from ⌘K or Ajustes › Busca: each one runs its
/// command without opening the search.
final class SearchHotKeys {
    private var registered: [String: (combo: KeyCombo, hotKey: GlobalHotKey)] = [:]
    /// Item ids whose combination another app already owns.
    private(set) var taken: Set<String> = []

    /// Matches the registrations to `hotKeys`, keeping the ones that didn't change.
    /// Releasing a `GlobalHotKey` unregisters it.
    func sync(_ hotKeys: [String: KeyCombo], run: @escaping (String) -> Void) {
        for (id, entry) in registered where hotKeys[id] != entry.combo {
            registered[id] = nil
        }
        taken = []
        for (id, combo) in hotKeys where registered[id] == nil {
            let hotKey = GlobalHotKey(keyCode: combo.keyCode, modifiers: combo.modifiers) { run(id) }
            if hotKey.isRegistered {
                registered[id] = (combo, hotKey)
            } else {
                taken.insert(id)
            }
        }
    }
}
