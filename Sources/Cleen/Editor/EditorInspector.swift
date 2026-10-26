import AppKit
import CleenKit
import SwiftUI

/// The raised panel on the right. With a clip or a zoom selected on the timeline it shows
/// that piece's settings, as Screen Studio does; otherwise the page picked beside it.
struct EditorInspector: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch editor.selection {
                case .clip(let id):
                    if let clip = editor.project.clips.first(where: { $0.id == id }) { EditorClipPage(clip: clip) }
                case .zoom(let id):
                    if let zoom = editor.project.zoom.first(where: { $0.id == id }) { EditorZoomPage(segment: zoom) }
                case nil:
                    switch editor.section {
                    case .background: EditorBackgroundPage()
                    case .cursor: EditorCursorPage()
                    case .camera: EditorCameraPage()
                    case .zoom: EditorZoomDefaultsPage()
                    case .audio: EditorAudioPage()
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.automatic)
        .background(EditorTheme.panel, in: .rect(cornerRadius: 19, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: editor.selection)
    }
}

/// A binding into the project that edits through the model (undo, redraw, save).
@MainActor
func projectBinding<T>(_ editor: EditorModel, _ path: WritableKeyPath<RecordingProject, T>) -> Binding<T> {
    Binding(get: { editor.project[keyPath: path] }, set: { value in editor.edit { $0[keyPath: path] = value } })
}

// MARK: Background

struct EditorBackgroundPage: View {
    @Environment(EditorModel.self) private var editor
    @State private var kind = Kind.wallpaper
    @State private var wallpapers: [URL] = []
    @State private var thumbnails: [URL: CGImage] = [:]

    enum Kind: Hashable {
        case wallpaper, gradient, color, image
    }

    var body: some View {
        EditorSection(title: "Fundo") {
            EditorPills(options: [(Kind.wallpaper, String(localized: "Papel de parede")), (.gradient, String(localized: "Gradiente")), (.color, String(localized: "Cor")), (.image, String(localized: "Imagem"))], selection: $kind)
            switch kind {
            case .wallpaper: wallpaperGrid
            case .gradient: gradientGrid
            case .color: colorGrid
            case .image: imagePicker
            }
        }
        .onAppear { kind = Self.kind(of: editor.style.background) }
        .task {
            let found = await Task.detached { WallpaperLibrary.pictures() }.value
            wallpapers = found
            for url in found where thumbnails[url] == nil {
                if let image = await Task.detached(operation: { WallpaperLibrary.thumbnail(url) }).value { thumbnails[url] = image }
            }
        }
        EditorDivider()
        EditorSection(title: "Desfoque do fundo") {
            EditorSlider(value: projectBinding(editor, \.style.backgroundBlur), range: 0...1)
        }
        EditorDivider()
        EditorSection(title: "Forma") {
            EditorSliderRow(title: "Margem", value: projectBinding(editor, \.style.padding), range: 0...0.2)
            EditorSliderRow(title: "Cantos arredondados", value: projectBinding(editor, \.style.roundness), range: 0...0.08)
            EditorSliderRow(title: "Sombra", value: projectBinding(editor, \.style.shadow), range: 0...1)
        }
    }

    private static func kind(of background: EditorStyle.Background) -> Kind {
        switch background {
        case .wallpaper: .wallpaper
        case .picture(let path): path.hasPrefix("/System/Library/Desktop Pictures") ? .wallpaper : .image
        case .gradient: .gradient
        case .color, .none: .color
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    private var wallpaperGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 7) {
                tile(selected: editor.style.background == .wallpaper, help: String(localized: "O papel de parede deste Mac")) {
                    editor.edit { $0.style.background = .wallpaper }
                } content: {
                    ZStack {
                        LinearGradient(colors: [Color(hex: 0x2B3A67), Color(hex: 0x5141F7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "desktopcomputer").font(.system(size: 13)).foregroundStyle(.white.opacity(0.9))
                    }
                }
                ForEach(wallpapers, id: \.self) { url in
                    tile(selected: editor.style.background == .picture(url.path(percentEncoded: false)), help: url.deletingPathExtension().lastPathComponent) {
                        editor.edit { $0.style.background = .picture(url.path(percentEncoded: false)) }
                    } content: {
                        if let image = thumbnails[url] {
                            Image(decorative: image, scale: 2).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            EditorTheme.controlSelected
                        }
                    }
                }
            }
            if !wallpapers.isEmpty {
                Button {
                    if let url = wallpapers.randomElement() { editor.edit { $0.style.background = .picture(url.path(percentEncoded: false)) } }
                } label: {
                    Label("Escolher um ao acaso", systemImage: "shuffle")
                }
                .buttonStyle(EditorSecondaryButtonStyle())
            }
        }
    }

    private var gradientGrid: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(BackgroundPresets.gradients.indices, id: \.self) { index in
                tile(selected: editor.style.background == .gradient(index)) {
                    editor.edit { $0.style.background = .gradient(index) }
                } content: {
                    BackgroundPresets.swatch(index)
                }
            }
        }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 8), spacing: 7) {
                ForEach(BackgroundPresets.solids, id: \.self) { hex in
                    tile(selected: editor.style.background == .color(hex)) {
                        editor.edit { $0.style.background = .color(hex) }
                    } content: {
                        BackgroundPresets.color(hex)
                    }
                }
            }
            ColorPicker(selection: Binding(get: { currentColor }, set: { color in
                editor.edit { $0.style.background = .color(Self.hex(color)) }
            }), supportsOpacity: false) {
                Text("Outra cor").font(EditorTheme.body).foregroundStyle(EditorTheme.secondary)
            }
            EditorToggleRow(title: "Sem fundo (só a gravação)", isOn: Binding(get: { editor.style.background == .none }, set: { off in
                editor.edit { $0.style.background = off ? .none : .gradient(0) }
            }))
        }
    }

    private var imagePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .picture(let path) = editor.style.background, !path.hasPrefix("/System/Library/Desktop Pictures"), let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
            }
            Button {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.image]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    editor.edit { $0.style.background = .picture(url.path(percentEncoded: false)) }
                }
            } label: {
                Label("Escolher uma imagem…", systemImage: "photo")
            }
            .buttonStyle(EditorSecondaryButtonStyle())
        }
    }

    private var currentColor: Color {
        if case .color(let hex) = editor.style.background { return BackgroundPresets.color(hex) }
        return .black
    }

    private static func hex(_ color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X", Int(ns.redComponent * 255), Int(ns.greenComponent * 255), Int(ns.blueComponent * 255))
    }

    private func tile(selected: Bool, help: String? = nil, action: @escaping () -> Void, @ViewBuilder content: () -> some View) -> some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { content() }
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.white : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help ?? "")
    }
}

// MARK: Cursor, camera, zoom, sound

struct EditorCursorPage: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        EditorSection(title: "Cursor", detail: "O ponteiro é redesenhado: maior, suave e com os cliques à mostra.") {
            EditorToggleRow(title: "Mostrar o cursor", isOn: projectBinding(editor, \.style.showsCursor))
            EditorSliderRow(title: "Tamanho", value: projectBinding(editor, \.style.cursorSize), range: 0.8...3) { "\($0.formatted(.number.precision(.fractionLength(1))))×" }
            EditorSliderRow(title: "Suavidade", value: projectBinding(editor, \.style.cursorSmoothing), range: 0...1)
        }
        EditorDivider()
        EditorSection(title: "Cliques") {
            EditorToggleRow(title: "Destacar os cliques", isOn: projectBinding(editor, \.style.showsClicks))
        }
    }
}

struct EditorCameraPage: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        EditorSection(title: "Câmera") {
            EditorToggleRow(title: "Mostrar a câmera", isOn: projectBinding(editor, \.style.camera.isVisible))
            EditorPills(options: [(EditorStyle.Layout.standard, String(localized: "No canto")), (.sideBySide, String(localized: "Lado a lado")), (.cameraOnly, String(localized: "Só a câmera"))], selection: projectBinding(editor, \.style.layout), fill: true)
        }
        if editor.style.layout == .standard {
            EditorDivider()
            EditorSection(title: "Bolha") {
                EditorPills(options: [(EditorStyle.Camera.Shape.rounded, String(localized: "Arredondada")), (.circle, String(localized: "Círculo")), (.square, String(localized: "Retângulo"))], selection: projectBinding(editor, \.style.camera.shape), fill: true)
                EditorSliderRow(title: "Tamanho", value: projectBinding(editor, \.style.camera.size), range: 0.12...0.5)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Canto").font(EditorTheme.body).foregroundStyle(EditorTheme.secondary)
                    EditorPills(options: [(EditorStyle.Camera.Corner.topLeft, "↖"), (.topRight, "↗"), (.bottomLeft, "↙"), (.bottomRight, "↘")], selection: projectBinding(editor, \.style.camera.corner), fill: true)
                }
            }
        }
    }
}

struct EditorZoomDefaultsPage: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        EditorSection(title: "Zoom", detail: "Os zooms aparecem na linha do tempo; clique num para mudar só ele.") {
            EditorToggleRow(title: "Zoom automático nos cliques", isOn: projectBinding(editor, \.style.autoZoom))
            EditorSliderRow(title: "Aproximação dos novos zooms", value: projectBinding(editor, \.style.zoomScale), range: 1.2...3.5) { "\($0.formatted(.number.precision(.fractionLength(1))))×" }
            Button {
                editor.addZoom()
            } label: {
                Label("Adicionar zoom no ponto atual", systemImage: "plus.magnifyingglass")
            }
            .buttonStyle(EditorSecondaryButtonStyle())
        }
    }
}

struct EditorAudioPage: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        EditorSection(title: "Som") {
            if editor.project.audio.contains(.microphone) { EditorToggleRow(title: "Silenciar o microfone", isOn: projectBinding(editor, \.style.mutesMicrophone)) }
            if editor.project.audio.contains(.system) { EditorToggleRow(title: "Silenciar o som do Mac", isOn: projectBinding(editor, \.style.mutesSystemAudio)) }
        }
    }
}

// MARK: Selected on the timeline

/// A clip's settings: its speed, and taking it out.
struct EditorClipPage: View {
    @Environment(EditorModel.self) private var editor
    let clip: ClipSegment
    private static let speeds: [Double] = [1, 1.2, 1.4, 1.6, 1.8, 2, 3]

    var body: some View {
        EditorSection(title: "Velocidade") {
            ScrollView(.horizontal) {
                EditorPills(options: Self.speeds.map { ($0, "\($0.formatted(.number.precision(.fractionLength(0...1))))x") }, selection: Binding(get: { clip.speed }, set: { editor.setSpeed($0, for: clip.id) }))
            }
            .scrollIndicators(.never)
            Button {
                editor.setSpeedForAll(clip.speed)
            } label: {
                Label("Usar esta velocidade em todos os cortes", systemImage: "gauge.with.needle")
                    .font(EditorTheme.body)
                    .foregroundStyle(EditorTheme.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(editor.project.clips.allSatisfy { $0.speed == clip.speed })
        }
        EditorDivider()
        EditorSection(title: "Duração") {
            Text(verbatim: "\(EditorTimeline.clock(clip.duration, hundredths: true)) · \(EditorTimeline.clock(clip.start, hundredths: true))–\(EditorTimeline.clock(clip.end, hundredths: true))")
                .font(EditorTheme.body.monospacedDigit())
                .foregroundStyle(EditorTheme.secondary)
            Button {
                editor.split(at: editor.currentTime)
            } label: {
                Label("Cortar no ponto atual", systemImage: "scissors")
            }
            .buttonStyle(EditorSecondaryButtonStyle())
        }
        EditorDivider()
        Button {
            editor.removeClip(clip.id)
        } label: {
            Label("Remover este corte", systemImage: "trash")
        }
        .buttonStyle(EditorSecondaryButtonStyle())
        .disabled(editor.project.clips.count < 2)
        .help(editor.project.clips.count < 2 ? "Divida antes com a tesoura: o vídeo precisa de pelo menos um corte" : "")
    }
}

/// A zoom's settings: how close, and whether it follows the cursor.
struct EditorZoomPage: View {
    @Environment(EditorModel.self) private var editor
    let segment: ZoomSegment

    var body: some View {
        EditorSection(title: "Zoom") {
            EditorSliderRow(title: "Aproximação", value: Binding(get: { segment.scale }, set: { value in editor.updateZoom(segment.id) { $0.scale = value } }), range: 1.2...4) { "\($0.formatted(.number.precision(.fractionLength(1))))×" }
            EditorPills(options: [(true, String(localized: "Segue o cursor")), (false, String(localized: "Ponto fixo"))], selection: Binding(get: { segment.focus == nil }, set: { follow in
                editor.updateZoom(segment.id) { $0.focus = follow ? nil : CGPoint(x: 0.5, y: 0.5) }
            }), fill: true)
        }
        if let focus = segment.focus {
            EditorDivider()
            EditorSection(title: "Onde olhar", detail: "Clique no ponto da tela que o zoom deve mostrar.") {
                EditorFocusPicker(focus: focus) { point in editor.updateZoom(segment.id) { $0.focus = point } }
            }
        }
        EditorDivider()
        Button {
            editor.removeZoom(segment.id)
        } label: {
            Label("Remover este zoom", systemImage: "trash")
        }
        .buttonStyle(EditorSecondaryButtonStyle())
    }
}

/// A small frame of the recording's shape with a dot to place where a fixed zoom looks.
struct EditorFocusPicker: View {
    @Environment(EditorModel.self) private var editor
    let focus: CGPoint
    let onChange: (CGPoint) -> Void

    var body: some View {
        let size = editor.project.croppedSize
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(EditorTheme.controlSelected)
                Circle()
                    .fill(EditorTheme.accentSoft)
                    .frame(width: 14, height: 14)
                    .position(x: focus.x * proxy.size.width, y: focus.y * proxy.size.height)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                onChange(CGPoint(x: min(1, max(0, drag.location.x / proxy.size.width)), y: min(1, max(0, drag.location.y / proxy.size.height))))
            })
        }
        .aspectRatio(size.width / max(1, size.height), contentMode: .fit)
    }
}
