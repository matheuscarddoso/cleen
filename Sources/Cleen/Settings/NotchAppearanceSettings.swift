import SwiftUI

struct NotchAppearanceSettings: View {
    @AppStorage(NotchSettings.openOnHoverKey) private var opensOnHover = true
    @AppStorage(NotchSettings.hoverDelayKey) private var hoverDelay = 0.12
    @AppStorage(NotchSettings.showsWingsKey) private var showsWings = true
    @AppStorage(NotchSettings.allScreensKey) private var allScreens = false

    var body: some View {
        NotchGroup {
            SettingRow(title: "Abrir") {
                NotchSegmented(options: [("Ao passar o mouse", true), ("Ao clicar", false)], selection: $opensOnHover)
            }
            if opensOnHover {
                SettingRow(title: "Atraso") {
                    NotchSegmented(options: [("Nenhum", 0.0), ("Curto", 0.12), ("Médio", 0.3), ("Longo", 0.6)], selection: $hoverDelay)
                }
            }
            SettingRow(title: "Indicadores com o notch fechado", note: "Disco e espaço livre; o que está tocando, quando houver.") {
                NotchSwitch(label: "Indicadores", isOn: $showsWings)
            }
            SettingRow(title: "Monitores externos", note: "Desenha um notch no topo de cada tela.") {
                NotchSwitch(label: "Monitores externos", isOn: $allScreens)
            }
        }
    }
}
