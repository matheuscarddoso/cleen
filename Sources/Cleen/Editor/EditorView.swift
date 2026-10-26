import AppKit
import CleenKit
import SwiftUI

/// The editor: the styled preview in the middle, the look on the right, the timeline
/// with the trim and the zooms at the bottom, and Export at the top.
struct EditorView: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar()
            HStack(spacing: 0) {
                EditorPreview(player: editor.player)
                    .aspectRatio(canvasAspect, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.09))
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                EditorInspector()
                    .frame(width: 300)
            }
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            EditorTimeline()
                .frame(height: 168)
        }
        .background(Color(white: 0.12))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onKeyPress(.space) {
            editor.togglePlay()
            return .handled
        }
        .onKeyPress(.delete) {
            guard let id = editor.selectedZoom else { return .ignored }
            editor.removeZoom(id)
            return .handled
        }
        .focusable()
        .focusEffectDisabled()
    }

    private var canvasAspect: CGFloat {
        let canvas = FrameGeometry.canvas(aspect: editor.style.aspect, source: editor.project.sourceSize, longSide: 1280)
        return canvas.width / max(1, canvas.height)
    }
}

/// The title strip: the take's name and Export (with its progress).
struct EditorTopBar: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            Text(editor.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            Spacer()
            exportControl
        }
        .padding(.leading, 80)
        .padding(.trailing, 14)
        .frame(height: 44)
        .background(Color(white: 0.14))
    }

    @ViewBuilder
    private var exportControl: some View {
        switch editor.exportState {
        case .idle:
            Button("Exportar") { editor.exportMovie() }
                .buttonStyle(EditorPrimaryButtonStyle())
                .keyboardShortcut("e", modifiers: .command)
        case .exporting(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress).frame(width: 120)
                Text(verbatim: "\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        case .done(let url):
            HStack(spacing: 8) {
                Button("Mostrar no Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    editor.dismissExport()
                }
                .buttonStyle(EditorSecondaryButtonStyle())
                Button("Copiar") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([url as NSURL])
                    editor.dismissExport()
                }
                .buttonStyle(EditorPrimaryButtonStyle())
            }
        case .failed(let message):
            HStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Button("OK") { editor.dismissExport() }
                    .buttonStyle(EditorSecondaryButtonStyle())
            }
        }
    }
}

struct EditorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Color.accentColor, in: .rect(cornerRadius: 7, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct EditorSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.1), in: .rect(cornerRadius: 7, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
