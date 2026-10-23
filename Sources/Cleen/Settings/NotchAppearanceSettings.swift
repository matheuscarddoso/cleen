import SwiftUI

struct NotchAppearanceSettings: View {
    @AppStorage(NotchSettings.openOnHoverKey) private var opensOnHover = true
    @AppStorage(NotchSettings.hoverDelayKey) private var hoverDelay = 0.12
    @AppStorage(NotchSettings.allScreensKey) private var allScreens = false
    @AppStorage(NotchSettings.panelWidthKey) private var panelWidth = 680.0
    @AppStorage(NotchSettings.panelHeightKey) private var panelHeight = 234.0

    var body: some View {
        NotchGroup {
            SettingRow(title: String(localized: "Abrir")) {
                NotchSegmented(options: [(String(localized: "Ao passar o mouse"), true), (String(localized: "Ao clicar"), false)], selection: $opensOnHover)
            }
            if opensOnHover {
                SettingRow(title: String(localized: "Atraso")) {
                    NotchSegmented(options: [(String(localized: "Nenhum"), 0.0), (String(localized: "Curto"), 0.12), (String(localized: "Médio"), 0.3), (String(localized: "Longo"), 0.6)], selection: $hoverDelay)
                }
            }
            SettingRow(title: String(localized: "Largura"), note: String(localized: "Mais largo cabe mais widgets no Início.")) {
                NotchSegmented(options: NotchSettings.widths, selection: $panelWidth)
            }
            SettingRow(title: String(localized: "Altura"), note: String(localized: "Mais alto mostra mais itens nas listas.")) {
                NotchSegmented(options: NotchSettings.heights, selection: $panelHeight)
            }
            SettingRow(title: String(localized: "Monitores externos"), note: String(localized: "Desenha um notch no topo de cada tela.")) {
                NotchSwitch(label: String(localized: "Monitores externos"), isOn: $allScreens)
            }
        }
    }
}
