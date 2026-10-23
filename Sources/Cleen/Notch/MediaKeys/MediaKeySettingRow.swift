import SwiftUI

/// Ajustes › Aparência: volume and brightness on the notch instead of the system's
/// display. Off until the person turns it on, since it needs Accessibility.
struct MediaKeySettingRow: View {
    @AppStorage(MediaKeyHUD.enabledKey) private var isOn = false
    @Environment(MediaKeyHUD.self) private var hud

    var body: some View {
        SettingRow(title: String(localized: "Volume e brilho no notch"), note: note) {
            NotchSwitch(label: String(localized: "Volume e brilho no notch"), isOn: $isOn)
        }
        .onChange(of: isOn) { _, on in hud.update(prompting: on) }
    }

    private var note: String {
        hud.isWaitingForAccess
            ? String(localized: "Permita o Cleen em Ajustes do Sistema › Privacidade › Acessibilidade para começar.")
            : String(localized: "As teclas de volume e brilho mostram o nível aqui, no lugar do aviso do macOS. Precisa da permissão de Acessibilidade.")
    }
}
