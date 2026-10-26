import AppKit
import CleenKit
import SwiftUI

/// The editor, laid out like Screen Studio's: the title bar with Export; the tools on the
/// left, the preview in the middle, the pages' icons and the inspector on the right; the
/// transport and the timeline along the bottom.
struct EditorView: View {
    @Environment(EditorModel.self) private var editor
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar()
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        EditorToolRail()
                            .padding(.leading, 15)
                            .padding(.top, 20)
                        EditorStage()
                            .padding(.horizontal, 20)
                        EditorSectionRail()
                            .padding(.top, 18)
                    }
                    .frame(maxHeight: .infinity)
                    EditorTransport()
                        .frame(height: 50)
                }
                EditorInspector()
                    .frame(width: 360)
                    .padding(.top, 16)
                    .padding(.leading, 14)
                    .padding(.trailing, 14)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
            EditorTimeline()
                .frame(height: 196)
        }
        .background(EditorTheme.window)
        .foregroundStyle(EditorTheme.primary)
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
        .onKeyPress(.space) {
            editor.togglePlay()
            return .handled
        }
        .onKeyPress(keys: [.delete, .deleteForward]) { _ in
            guard editor.selection != nil else { return .ignored }
            editor.removeSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            if editor.isCutting {
                editor.isCutting = false
                return .handled
            }
            guard editor.selection != nil else { return .ignored }
            editor.selection = nil
            return .handled
        }
        .onKeyPress("c") {
            editor.split(at: editor.currentTime)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            editor.seek(to: editor.currentTime - 1.0 / Double(editor.project.export.framesPerSecond) * 6)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            editor.seek(to: editor.currentTime + 1.0 / Double(editor.project.export.framesPerSecond) * 6)
            return .handled
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
    }
}

/// The title bar: the folder and the trash by the window buttons, the take's name in
/// the middle, then shortcuts, undo, redo and Export.
struct EditorTopBar: View {
    @Environment(EditorModel.self) private var editor
    @State private var confirmsTrash = false
    @State private var showsShortcuts = false
    @State private var showsExport = false

    var body: some View {
        HStack(spacing: 4) {
            Button { editor.revealInFinder() } label: { Image(systemName: "folder") }
                .buttonStyle(EditorIconButtonStyle())
                .help("Mostrar a gravação no Finder")
            Button { confirmsTrash = true } label: { Image(systemName: "trash") }
                .buttonStyle(EditorIconButtonStyle())
                .help("Apagar a gravação")
                .confirmationDialog("Mover esta gravação para o Lixo?", isPresented: $confirmsTrash) {
                    Button("Mover para o Lixo", role: .destructive) {
                        if editor.moveToTrash() { NSApp.keyWindow?.close() }
                    }
                } message: {
                    Text("Dá para trazer de volta pelo Lixo.")
                }
            Spacer(minLength: 20)
            title
            Spacer(minLength: 20)
            Button { showsShortcuts.toggle() } label: { Image(systemName: "command") }
                .buttonStyle(EditorIconButtonStyle())
                .help("Atalhos de teclado")
                .popover(isPresented: $showsShortcuts, arrowEdge: .bottom) { EditorShortcuts() }
            separator
            Button { editor.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(EditorIconButtonStyle())
                .disabled(!editor.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("Desfazer")
            Button { editor.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(EditorIconButtonStyle())
                .disabled(!editor.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("Refazer")
            separator
            Button { showsExport.toggle() } label: {
                Label("Exportar", systemImage: "square.and.arrow.up.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(EditorPrimaryButtonStyle())
            .keyboardShortcut("e", modifiers: .command)
            .popover(isPresented: $showsExport, arrowEdge: .bottom) { EditorExportPanel() }
            .padding(.leading, 6)
        }
        .padding(.leading, 84)
        .padding(.trailing, 14)
        .frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(EditorTheme.separator).frame(height: 1) }
    }

    private var title: some View {
        (Text(editor.name).foregroundStyle(EditorTheme.primary)
            + Text(verbatim: ".\(RecordingProject.folderExtension)").foregroundStyle(EditorTheme.tertiary))
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var separator: some View {
        Rectangle().fill(EditorTheme.separator).frame(width: 1, height: 22).padding(.horizontal, 8)
    }
}

/// Export's popover: the size and smoothness, then the button; progress and the result
/// take its place.
struct EditorExportPanel: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exportar")
                .font(EditorTheme.title)
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolução").font(EditorTheme.body).foregroundStyle(EditorTheme.secondary)
                EditorPills(options: ExportOptions.Resolution.allCases.map { ($0, $0.rawValue) }, selection: binding(\.export.resolution), fill: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Quadros por segundo").font(EditorTheme.body).foregroundStyle(EditorTheme.secondary)
                EditorPills(options: [(30, "30 fps"), (60, "60 fps")], selection: binding(\.export.framesPerSecond), fill: true)
            }
            let canvas = editor.canvasSize(longSide: editor.project.export.resolution.longSide)
            Text(verbatim: "MP4 · HEVC · \(Int(canvas.width))×\(Int(canvas.height)) · \(EditorTimeline.clock(editor.duration))")
                .font(EditorTheme.caption.monospacedDigit())
                .foregroundStyle(EditorTheme.tertiary)
            result
        }
        .padding(18)
        .frame(width: 320)
        .background(EditorTheme.panel)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var result: some View {
        switch editor.exportState {
        case .idle:
            Button { editor.exportMovie() } label: {
                Label("Exportar para Filmes › Cleen", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EditorPrimaryButtonStyle())
        case .exporting(let progress):
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress).tint(EditorTheme.accent)
                Text(verbatim: "\(Int(progress * 100))%")
                    .font(EditorTheme.caption.monospacedDigit())
                    .foregroundStyle(EditorTheme.secondary)
            }
        case .done(let url):
            VStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([url as NSURL])
                } label: {
                    Label("Copiar o vídeo", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .buttonStyle(EditorPrimaryButtonStyle())
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Mostrar no Finder", systemImage: "folder")
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                Button("Exportar de novo") { editor.dismissExport() }
                    .buttonStyle(.plain)
                    .font(EditorTheme.body)
                    .foregroundStyle(EditorTheme.tertiary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(EditorTheme.body)
                    .foregroundStyle(.orange)
                Button("Tentar de novo") { editor.dismissExport() }
                    .buttonStyle(EditorSecondaryButtonStyle())
            }
        }
    }

    private func binding<T>(_ path: WritableKeyPath<RecordingProject, T>) -> Binding<T> {
        Binding(get: { editor.project[keyPath: path] }, set: { value in editor.edit { $0[keyPath: path] = value } })
    }
}

/// The editor's keyboard shortcuts.
struct EditorShortcuts: View {
    private let rows: [(String, LocalizedStringKey)] = [
        ("Espaço", "Reproduzir ou pausar"),
        ("C", "Cortar no ponto atual"),
        ("← →", "Voltar ou avançar um pouco"),
        ("⌫", "Apagar o corte ou o zoom selecionado"),
        ("Esc", "Soltar a seleção ou guardar a tesoura"),
        ("⌘Z", "Desfazer"),
        ("⇧⌘Z", "Refazer"),
        ("⌘E", "Exportar"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Atalhos").font(EditorTheme.title)
            ForEach(rows, id: \.0) { key, action in
                HStack {
                    Text(action).font(EditorTheme.body).foregroundStyle(EditorTheme.secondary)
                    Spacer(minLength: 24)
                    Text(verbatim: key)
                        .font(.system(size: 12, weight: .medium).monospaced())
                        .padding(.horizontal, 7)
                        .frame(minHeight: 22)
                        .background(EditorTheme.controlSelected, in: .rect(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(EditorTheme.panel)
        .environment(\.colorScheme, .dark)
    }
}
