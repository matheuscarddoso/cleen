import SwiftUI

/// The "…" button: pause the history or wipe it.
struct ClipboardMoreMenu: View {
    @Environment(ClipboardModel.self) private var model
    @AppStorage(ClipboardModel.enabledKey) private var enabled = true

    var body: some View {
        Menu {
            Toggle("Guardar o que eu copiar", isOn: $enabled)
            Divider()
            Button("Apagar histórico", role: .destructive, action: model.clear)
                .disabled(model.log.entries.isEmpty)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 26, height: 26)
                .background(NotchStyle.control, in: .circle)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Mais opções")
    }
}
