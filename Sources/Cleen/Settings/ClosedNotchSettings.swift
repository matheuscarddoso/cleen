import SwiftUI

/// What the closed notch shows: the indicator beside the camera when nothing's going
/// on, the live activities that take over for a moment, and full-screen behavior.
struct ClosedNotchSettings: View {
    @AppStorage(NotchSettings.showsWingsKey) private var showsWings = true
    @AppStorage(LiveActivitySettings.idleKey) private var idle = LiveActivitySettings.Idle.disk.rawValue
    @AppStorage(LiveActivitySettings.powerKey) private var power = true
    @AppStorage(LiveActivitySettings.headphonesKey) private var headphones = true
    @AppStorage(LiveActivitySettings.trackKey) private var track = true
    @AppStorage(LiveActivitySettings.meetingKey) private var meeting = true
    @AppStorage(LiveActivitySettings.agentsKey) private var agents = true
    @AppStorage(LiveActivitySettings.hideInFullscreenKey) private var hidesInFullscreen = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notch fechado")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .padding(.leading, 4)
                .padding(.top, 6)
            NotchGroup {
                SettingRow(title: String(localized: "Indicadores ao lado da câmera"), note: String(localized: "O que está tocando, avisos e o indicador abaixo.")) {
                    NotchSwitch(label: String(localized: "Indicadores"), isOn: $showsWings)
                }
                if showsWings {
                    SettingRow(title: String(localized: "Quando nada acontece")) {
                        NotchSegmented(options: LiveActivitySettings.Idle.allCases.map { ($0.label, $0.rawValue) }, selection: $idle)
                    }
                    SettingRow(title: String(localized: "Carregador e bateria"), note: String(localized: "Ao ligar ou tirar da tomada, com a carga completa e com bateria fraca.")) {
                        NotchSwitch(label: String(localized: "Carregador e bateria"), isOn: $power)
                    }
                    SettingRow(title: String(localized: "Fones"), note: String(localized: "AirPods e outros fones sem fio conectando.")) {
                        NotchSwitch(label: String(localized: "Fones"), isOn: $headphones)
                    }
                    SettingRow(title: String(localized: "Música nova"), note: String(localized: "O nome da faixa por um instante quando ela troca.")) {
                        NotchSwitch(label: String(localized: "Música nova"), isOn: $track)
                    }
                    SettingRow(title: String(localized: "Próxima reunião"), note: String(localized: "Dez minutos antes de um evento do Calendário.")) {
                        NotchSwitch(label: String(localized: "Próxima reunião"), isOn: $meeting)
                    }
                    SettingRow(title: String(localized: "Claude Code"), note: String(localized: "Quando uma sessão termina e fica esperando você.")) {
                        NotchSwitch(label: String(localized: "Claude Code"), isOn: $agents)
                    }
                    SettingRow(title: String(localized: "Esconder em tela cheia"), note: String(localized: "Durante um vídeo ou apresentação, o notch fica só preto.")) {
                        NotchSwitch(label: String(localized: "Esconder em tela cheia"), isOn: $hidesInFullscreen)
                    }
                }
                MediaKeySettingRow()
            }
        }
        .animation(.smooth(duration: 0.25), value: showsWings)
    }
}
