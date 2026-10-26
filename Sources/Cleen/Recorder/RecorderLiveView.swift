import AVFoundation
import AppKit
import SwiftUI

/// While recording: the time and the two ways out, Stop (opens the editor) and Discard.
struct RecorderLiveView: View {
    @Environment(RecorderModel.self) private var recorder
    @Environment(NotchState.self) private var notch

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .phaseAnimator([1.0, 0.35]) { dot, opacity in dot.opacity(opacity) } animation: { _ in .easeInOut(duration: 0.8) }
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text(RecorderElapsed.text(from: recorder.recordingStart, to: context.date))
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NotchStyle.primary)
                }
            }
            Spacer()
            if recorder.state == .finishing {
                ProgressView().controlSize(.small)
                Text("Salvando…")
                    .font(NotchStyle.bodyMedium)
                    .foregroundStyle(NotchStyle.secondary)
            } else {
                Button("Descartar", role: .destructive) { reviewDiscard() }
                    .buttonStyle(.notchSecondary)
                Button {
                    Task { await recorder.stop() }
                } label: {
                    Label("Parar", systemImage: "stop.fill")
                }
                .buttonStyle(.notchPrimary)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 8)
    }

    private func reviewDiscard() {
        notch.review(DeletionReview(
            title: String(localized: "Descartar a gravação?"),
            items: [DeletionReview.Item(id: "take", name: String(localized: "Gravação em andamento"), detail: RecorderElapsed.text(from: recorder.recordingStart, to: .now), symbol: "record.circle")],
            outcome: .delete,
            confirm: { Task { await recorder.discard() } }
        ))
    }
}

struct RecorderCountdownView: View {
    let value: Int
    @Environment(RecorderModel.self) private var recorder

    var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: "\(value)")
                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                .foregroundStyle(NotchStyle.primary)
                .contentTransition(.numericText(countsDown: true))
            Text("A gravação começa já")
                .font(NotchStyle.bodyMedium)
                .foregroundStyle(NotchStyle.secondary)
            Spacer()
            Button("Cancelar") { recorder.cancelCountdown() }
                .buttonStyle(.notchSecondary)
        }
        .padding(.horizontal, 8)
    }
}

enum RecorderElapsed {
    /// "0:07", "12:40", "1:02:03".
    static func text(from start: Date?, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start ?? now)))
        let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Right after a take: its first frame and what to do with it, Screen Studio's quick
/// share widget in the notch.
struct RecorderQuickShare: View {
    let folder: URL
    @Environment(AppModel.self) private var app
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                } else {
                    NotchStyle.control
                }
            }
            .frame(width: 96, height: 54)
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(NotchStyle.cardStroke) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Gravação pronta")
                    .font(NotchStyle.headline)
                    .foregroundStyle(NotchStyle.primary)
                Text(folder.deletingPathExtension().lastPathComponent)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            NotchIconButton(symbol: "folder", help: String(localized: "Mostrar no Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            }
            Button("Editar") { app.openEditor(folder) }
                .buttonStyle(.notchPrimary)
        }
        .padding(8)
        .background(NotchStyle.card, in: .rect(cornerRadius: 14, style: .continuous))
        .task(id: folder) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.appending(path: "screen.mov")))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 180)
            if let image = try? await generator.image(at: .zero).image {
                thumbnail = NSImage(cgImage: image, size: .zero)
            }
        }
    }
}
