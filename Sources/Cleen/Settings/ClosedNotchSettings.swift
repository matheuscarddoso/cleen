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
    @AppStorage(LiveActivitySettings.hideInFullscreenKey) private var hidesInFullscreen = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notch fechado")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .padding(.leading, 4)
                .padding(.top, 6)
            NotchGroup {
                SettingRow(title: "Indicadores ao lado da câmera", note: "O que está tocando, avisos e o indicador abaixo.") {
                    NotchSwitch(label: "Indicadores", isOn: $showsWings)
                }
                if showsWings {
                    SettingRow(title: "Quando nada acontece") {
                        NotchSegmented(options: LiveActivitySettings.Idle.allCases.map { ($0.label, $0.rawValue) }, selection: $idle)
                    }
                    SettingRow(title: "Carregador e bateria", note: "Ao ligar ou tirar da tomada, com a carga completa e com bateria fraca.") {
                        NotchSwitch(label: "Carregador e bateria", isOn: $power)
                    }
                    SettingRow(title: "Fones", note: "AirPods e outros fones sem fio conectando.") {
                        NotchSwitch(label: "Fones", isOn: $headphones)
                    }
                    SettingRow(title: "Música nova", note: "O nome da faixa por um instante quando ela troca.") {
                        NotchSwitch(label: "Música nova", isOn: $track)
                    }
                    SettingRow(title: "Próxima reunião", note: "Dez minutos antes de um evento do Calendário.") {
                        NotchSwitch(label: "Próxima reunião", isOn: $meeting)
                    }
                    SettingRow(title: "Esconder em tela cheia", note: "Durante um vídeo ou apresentação, o notch fica só preto.") {
                        NotchSwitch(label: "Esconder em tela cheia", isOn: $hidesInFullscreen)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: showsWings)
    }
}
