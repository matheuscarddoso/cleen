import CleenKit
import SwiftUI

/// An on/off switch for one launch item. Flipping it asks launchd; the list then
/// reloads, and this view is rebuilt from the real state (see `.id` at the call site).
struct LaunchItemSwitch: View {
    @Environment(StartupModel.self) private var model
    let item: LaunchItem
    @State private var isOn: Bool

    init(item: LaunchItem) {
        self.item = item
        _isOn = State(initialValue: !item.isDisabled)
    }

    var body: some View {
        Toggle(item.displayName, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .help(item.scope.needsAdministrator ? "Pede a senha de administrador" : "Ligar ou desligar")
            .onChange(of: isOn) { _, enabled in
                Task { await model.setEnabled(enabled, for: item) }
            }
    }
}
