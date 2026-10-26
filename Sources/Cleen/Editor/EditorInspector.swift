import CleenKit
import SwiftUI

/// The look of the take, Screen Studio's right column: background, frame, cursor, zoom,
/// camera, sound and export size.
struct EditorInspector: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Fundo") {
                    backgroundPicker
                    slider("Margem", value: \.style.padding, range: 0...0.2)
                    slider("Cantos", value: \.style.roundness, range: 0...0.08)
                    slider("Sombra", value: \.style.shadow, range: 0...1)
                }
                section("Formato") {
                    Picker("Formato", selection: binding(\.style.aspect)) {
                        Text("Original").tag(EditorStyle.Aspect.source)
                        ForEach([EditorStyle.Aspect.wide, .vertical, .square, .classic], id: \.self) { aspect in
                            Text(verbatim: aspect.rawValue).tag(aspect)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                section("Cursor") {
                    toggle("Mostrar o cursor", \.style.showsCursor)
                    slider("Tamanho", value: \.style.cursorSize, range: 0.8...3)
                    slider("Suavidade", value: \.style.cursorSmoothing, range: 0...1)
                    toggle("Destacar os cliques", \.style.showsClicks)
                }
                section("Zoom") {
                    toggle("Zoom automático nos cliques", \.style.autoZoom)
                    slider("Aproximação", value: \.style.zoomScale, range: 1.2...3.5)
                    selectedZoomControls
                    Button("Adicionar zoom aqui") { editor.addZoom() }
                        .buttonStyle(EditorSecondaryButtonStyle())
                }
                if editor.project.hasCamera {
                    section("Câmera") {
                        toggle("Mostrar a câmera", \.style.camera.isVisible)
                        Picker("Canto", selection: binding(\.style.camera.corner)) {
                            Image(systemName: "arrow.up.left").tag(EditorStyle.Camera.Corner.topLeft)
                            Image(systemName: "arrow.up.right").tag(EditorStyle.Camera.Corner.topRight)
                            Image(systemName: "arrow.down.left").tag(EditorStyle.Camera.Corner.bottomLeft)
                            Image(systemName: "arrow.down.right").tag(EditorStyle.Camera.Corner.bottomRight)
                        }
                        .pickerStyle(.segmented)
                        slider("Tamanho", value: \.style.camera.size, range: 0.12...0.5)
                        Picker("Forma", selection: binding(\.style.camera.shape)) {
                            Text("Círculo").tag(EditorStyle.Camera.Shape.circle)
                            Text("Arredondada").tag(EditorStyle.Camera.Shape.rounded)
                            Text("Quadrada").tag(EditorStyle.Camera.Shape.square)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if !editor.project.audio.isEmpty {
                    section("Som") {
                        if editor.project.audio.contains(.microphone) { toggle("Silenciar o microfone", \.style.mutesMicrophone) }
                        if editor.project.audio.contains(.system) { toggle("Silenciar o som do Mac", \.style.mutesSystemAudio) }
                    }
                }
                section("Exportar") {
                    Picker("Resolução", selection: binding(\.export.resolution)) {
                        ForEach(ExportOptions.Resolution.allCases, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Quadros por segundo", selection: binding(\.export.framesPerSecond)) {
                        Text(verbatim: "30 fps").tag(30)
                        Text(verbatim: "60 fps").tag(60)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.never)
        .background(Color(white: 0.13))
    }

    // MARK: Background

    private var backgroundPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(BackgroundPresets.gradients.indices, id: \.self) { index in
                swatch(BackgroundPresets.swatch(index), selected: editor.style.background == .gradient(index)) {
                    editor.edit { $0.style.background = .gradient(index) }
                }
            }
            swatch(Color(white: 0.92), selected: editor.style.background == .color("#EBEBEB")) {
                editor.edit { $0.style.background = .color("#EBEBEB") }
            }
            swatch(Color.black, selected: editor.style.background == .color("#000000")) {
                editor.edit { $0.style.background = .color("#000000") }
            }
            swatch(LinearGradient(colors: [.teal, .indigo], startPoint: .top, endPoint: .bottom), selected: editor.style.background == .wallpaper, symbol: "photo") {
                editor.edit { $0.style.background = .wallpaper }
            }
            swatch(Color(white: 0.2), selected: editor.style.background == .none, symbol: "rectangle.slash") {
                editor.edit { $0.style.background = .none }
            }
        }
    }

    private func swatch(_ fill: some ShapeStyle, selected: Bool, symbol: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fill)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let symbol {
                        Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.1), lineWidth: selected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Zoom

    @ViewBuilder
    private var selectedZoomControls: some View {
        if let id = editor.selectedZoom, let segment = editor.project.zoom.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Zoom selecionado")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(role: .destructive) { editor.removeZoom(id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.7))
                        .help("Tirar este zoom")
                }
                HStack {
                    Text("Aproximação")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    Slider(value: Binding(get: { segment.scale }, set: { value in editor.updateZoom(id) { $0.scale = value } }), in: 1.2...4)
                }
                Toggle("Seguir o cursor", isOn: Binding(get: { segment.focus == nil }, set: { follow in
                    editor.updateZoom(id) { $0.focus = follow ? nil : CGPoint(x: 0.5, y: 0.5) }
                }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
            }
            .padding(10)
            .background(Color.white.opacity(0.05), in: .rect(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: Controls

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
            content()
        }
    }

    private func slider(_ title: LocalizedStringKey, value: WritableKeyPath<RecordingProject, Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 82, alignment: .leading)
            Slider(value: binding(value), in: range)
                .controlSize(.small)
        }
    }

    private func toggle(_ title: LocalizedStringKey, _ value: WritableKeyPath<RecordingProject, Bool>) -> some View {
        Toggle(title, isOn: binding(value))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 12))
    }

    private func binding<T>(_ path: WritableKeyPath<RecordingProject, T>) -> Binding<T> {
        Binding(get: { editor.project[keyPath: path] }, set: { value in editor.edit { $0[keyPath: path] = value } })
    }
}
