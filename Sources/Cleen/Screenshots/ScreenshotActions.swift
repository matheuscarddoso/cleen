import SwiftUI

/// What to do with the capture, as a compact grid that fits beside the preview.
struct ScreenshotActions: View {
    @Environment(ScreenshotModel.self) private var model
    let shot: Screenshot
    @State private var copied = false

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                Button(action: copy) {
                    Label(copied ? String(localized: "Copiado") : String(localized: "Copiar"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.notchPrimary)
                ShareLink(item: shot.url) {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.notchSecondary)
            }
            GridRow {
                Button { model.airDrop(shot) } label: {
                    Label("AirDrop", systemImage: "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.notchSecondary)
                Button { model.reveal(shot) } label: {
                    Label("No Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.notchSecondary)
            }
            GridRow {
                Button { model.delete(shot) } label: {
                    Label("Excluir", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(NotchStyle.critical)
                }
                .buttonStyle(.notchSecondary)
                .gridCellColumns(2)
            }
        }
        .labelStyle(.titleAndIcon)
        .animation(.smooth(duration: 0.15), value: copied)
        .onChange(of: shot.id) { copied = false }
    }

    private func copy() {
        model.copy(shot)
        copied = true
    }
}
