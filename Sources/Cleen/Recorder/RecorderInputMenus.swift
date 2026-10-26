import SwiftUI

/// Camera: which one (or none), the preview and the highest resolution, like Screen
/// Studio's camera menu.
struct RecorderCameraMenu: View {
    @Environment(RecorderModel.self) private var recorder
    @State private var cameras: [CaptureDevices.Device] = []

    var body: some View {
        @Bindable var recorder = recorder
        Menu {
            ForEach(cameras) { camera in
                Toggle(isOn: Binding(get: { recorder.cameraID == camera.id }, set: { if $0 { recorder.cameraID = camera.id } })) {
                    Text(camera.isDefault ? String(localized: "\(camera.name) (padrão)") : camera.name)
                }
            }
            Toggle("Não gravar a câmera", isOn: Binding(get: { recorder.cameraID == nil }, set: { if $0 { recorder.cameraID = nil } }))
            Divider()
            Toggle("Mostrar a prévia da câmera", isOn: $recorder.showsCameraPreview)
            Picker("Resolução máxima", selection: $recorder.cameraMaxHeight) {
                Text(verbatim: "720p").tag(720)
                Text(verbatim: "1080p").tag(1080)
                Text(verbatim: "4K").tag(2160)
            }
        } label: {
            RecorderInputLabel(symbol: recorder.cameraID == nil ? "video.slash" : "video", title: title, isOn: recorder.cameraID != nil)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onAppear { cameras = CaptureDevices.cameras() }
    }

    private var title: String {
        guard let id = recorder.cameraID else { return String(localized: "Sem câmera") }
        return cameras.first { $0.id == id }?.name ?? String(localized: "Câmera")
    }
}

struct RecorderMicrophoneMenu: View {
    @Environment(RecorderModel.self) private var recorder
    @State private var microphones: [CaptureDevices.Device] = []

    var body: some View {
        Menu {
            ForEach(microphones) { microphone in
                Toggle(isOn: Binding(get: { recorder.microphoneID == microphone.id }, set: { if $0 { recorder.microphoneID = microphone.id } })) {
                    Text(microphone.isDefault ? String(localized: "\(microphone.name) (padrão)") : microphone.name)
                }
            }
            Toggle("Não gravar o microfone", isOn: Binding(get: { recorder.microphoneID == nil }, set: { if $0 { recorder.microphoneID = nil } }))
        } label: {
            RecorderInputLabel(symbol: recorder.microphoneID == nil ? "mic.slash" : "mic", title: title, isOn: recorder.microphoneID != nil)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onAppear { microphones = CaptureDevices.microphones() }
    }

    private var title: String {
        guard let id = recorder.microphoneID else { return String(localized: "Sem microfone") }
        return microphones.first { $0.id == id }?.name ?? String(localized: "Microfone")
    }
}

/// The Mac's own sound, on or off.
struct RecorderSystemAudioButton: View {
    @Environment(RecorderModel.self) private var recorder

    var body: some View {
        Button {
            recorder.recordsSystemAudio.toggle()
        } label: {
            RecorderInputLabel(symbol: recorder.recordsSystemAudio ? "speaker.wave.2" : "speaker.slash",
                               title: recorder.recordsSystemAudio ? String(localized: "Som do Mac") : String(localized: "Sem som do Mac"),
                               isOn: recorder.recordsSystemAudio)
        }
        .buttonStyle(.plain)
        .help("Gravar o som que sai do Mac")
    }
}

/// An input in the bar: its icon and what's picked, dimmed when off.
struct RecorderInputLabel: View {
    let symbol: String
    let title: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .truncationMode(.tail)
        }
        .opacity(isOn ? 1 : 0.6)
        .padding(.horizontal, 8)
        .frame(maxWidth: 150, minHeight: 40)
        // What's picked keeps a quiet backdrop of its own, as in Screen Studio.
        .background(isOn ? NotchStyle.control : .clear, in: .rect(cornerRadius: 10, style: .continuous))
        .contentShape(.rect)
        .toolbarHoverItem(title)
    }
}

/// The gear: before, during and after recording, as Screen Studio's options menu.
struct RecorderOptionsMenu: View {
    @Environment(RecorderModel.self) private var recorder

    var body: some View {
        @Bindable var recorder = recorder
        Menu {
            Section("Antes de gravar") {
                Picker("Contagem regressiva", selection: $recorder.countdown) {
                    Text("Desligada").tag(0)
                    Text(verbatim: "3 s").tag(3)
                    Text(verbatim: "5 s").tag(5)
                    Text(verbatim: "10 s").tag(10)
                }
            }
            Section("Durante a gravação") {
                Toggle("Ocultar os ícones da mesa", isOn: $recorder.hidesDesktopIcons)
                Toggle("Ocultar o Dock", isOn: $recorder.hidesDock)
                Toggle("Destacar a área gravada", isOn: $recorder.highlightsArea)
                Toggle("Mostrar as notas do apresentador", isOn: $recorder.showsSpeakerNotes)
            }
            Section("Depois de gravar") {
                Toggle("Abrir o Quick Share", isOn: $recorder.opensQuickShare)
            }
            Menu("Avançado") {
                Picker("Quadros por segundo", selection: $recorder.framesPerSecond) {
                    Text(verbatim: "30").tag(30)
                    Text(verbatim: "60").tag(60)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .frame(width: 44, height: 40)
            .contentShape(.rect)
            .toolbarHoverItem("options")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Opções da gravação")
    }
}
