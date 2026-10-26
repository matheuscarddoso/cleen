import CleenKit
import SwiftUI

/// The tools down the left, Screen Studio's: the zooms on top, then where the camera goes.
struct EditorToolRail: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        VStack(spacing: 8) {
            tool("plus.magnifyingglass", help: "Zoom automático nos cliques", isOn: editor.style.autoZoom) {
                editor.edit { $0.style.autoZoom.toggle() }
            }
            tool("magnifyingglass", help: "Adicionar um zoom no ponto atual") { editor.addZoom() }
            if editor.project.hasCamera {
                divider
                tool("rectangle.inset.bottomright.filled", help: "Tela com a câmera no canto", isOn: editor.style.layout == .standard && editor.style.camera.isVisible) {
                    editor.edit {
                        $0.style.layout = .standard
                        $0.style.camera.isVisible = true
                    }
                }
                tool("rectangle.split.2x1", help: "Tela e câmera lado a lado", isOn: editor.style.layout == .sideBySide && editor.style.camera.isVisible) {
                    editor.edit {
                        $0.style.layout = .sideBySide
                        $0.style.camera.isVisible = true
                    }
                }
                tool("person.crop.square", help: "Só a câmera", isOn: editor.style.layout == .cameraOnly && editor.style.camera.isVisible) {
                    editor.edit {
                        $0.style.layout = .cameraOnly
                        $0.style.camera.isVisible = true
                    }
                }
                tool("person.slash", help: "Sem a câmera", isOn: !editor.style.camera.isVisible) {
                    editor.edit { $0.style.camera.isVisible = false }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(width: 48)
        .background(EditorTheme.rail, in: .rect(cornerRadius: 15, style: .continuous))
    }

    private func tool(_ symbol: String, help: LocalizedStringKey, isOn: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(EditorIconButtonStyle(size: 36, isOn: isOn))
            .help(help)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 22, height: 1).padding(.vertical, 6)
    }
}

/// The inspector's pages, as icons beside it. Picking one lets go of what was selected
/// on the timeline, as the timeline's settings take the inspector while selected.
struct EditorSectionRail: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        VStack(spacing: 14) {
            ForEach(sections, id: \.0) { section, symbol, help in
                let isOn = editor.selection == nil && editor.section == section
                Button {
                    editor.selection = nil
                    editor.section = section
                } label: {
                    Image(systemName: symbol)
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(EditorTheme.accentSoft)
                                .frame(width: 4, height: 4)
                                .offset(x: 9)
                                .opacity(isOn ? 1 : 0)
                        }
                }
                .buttonStyle(EditorIconButtonStyle(size: 38, isOn: isOn))
                .help(help)
            }
        }
        .frame(width: 44)
        .animation(.easeOut(duration: 0.15), value: editor.section)
    }

    private var sections: [(EditorModel.InspectorSection, String, LocalizedStringKey)] {
        var all: [(EditorModel.InspectorSection, String, LocalizedStringKey)] = [
            (.background, "rectangle.inset.filled", "Fundo"),
            (.cursor, "cursorarrow", "Cursor"),
        ]
        if editor.project.hasCamera { all.append((.camera, "person.crop.rectangle", "Câmera")) }
        all.append((.zoom, "plus.magnifyingglass", "Zoom"))
        if !editor.project.audio.isEmpty { all.append((.audio, "speaker.wave.2", "Som")) }
        return all
    }
}

/// Under the preview: the scissors on the left, play in the middle with the time on
/// either side, the timeline's magnification on the right.
struct EditorTransport: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        @Bindable var editor = editor
        ZStack {
            HStack(spacing: 0) {
                Button { editor.isCuttingLocked.toggle() } label: { Image(systemName: "scissors") }
                    .buttonStyle(EditorIconButtonStyle(size: 36, isOn: editor.isCutting))
                    .help("Tesoura: clique num corte da linha do tempo para dividi-lo (C corta no ponto atual)")
                    .padding(.leading, 21)
                Spacer()
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(EditorTheme.secondary)
                    .help("Aproximar a linha do tempo")
                Rectangle().fill(EditorTheme.separator).frame(width: 1, height: 22).padding(.horizontal, 12)
                Text(verbatim: "\(editor.timelineZoom.formatted(.number.precision(.fractionLength(0...1))))×")
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .frame(width: 34, alignment: .trailing)
                EditorSlider(value: $editor.timelineZoom, range: 1...10)
                    .frame(width: 104)
                    .padding(.leading, 8)
                    .padding(.trailing, 18)
            }
            HStack(spacing: 14) {
                Text(verbatim: EditorTimeline.clock(editor.currentTime, hundredths: true))
                    .foregroundStyle(EditorTheme.tertiary)
                    .frame(width: 76, alignment: .trailing)
                Button { editor.seekBackward() } label: { Image(systemName: "backward.end") }
                    .buttonStyle(EditorIconButtonStyle(size: 34))
                    .help("Início do corte")
                Button { editor.togglePlay() } label: {
                    Image(systemName: editor.isPlaying ? "pause.circle" : "play.circle")
                        .font(.system(size: 26, weight: .light))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(EditorIconButtonStyle(size: 40))
                .help(editor.isPlaying ? "Pausar (espaço)" : "Reproduzir (espaço)")
                Button { editor.seekForward() } label: { Image(systemName: "forward.end") }
                    .buttonStyle(EditorIconButtonStyle(size: 34))
                    .help("Próximo corte")
                Text(verbatim: EditorTimeline.clock(editor.duration, hundredths: true))
                    .foregroundStyle(EditorTheme.tertiary)
                    .frame(width: 76, alignment: .leading)
            }
            .font(.system(size: 15, weight: .regular).monospacedDigit())
        }
    }
}
