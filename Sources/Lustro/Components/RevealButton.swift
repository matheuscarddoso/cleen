import AppKit
import SwiftUI

/// Shows the file in Finder: the escape hatch for "what is this, actually?".
struct RevealButton: View {
    let url: URL

    var body: some View {
        Button("Mostrar no Finder", systemImage: "arrow.up.forward.square", action: reveal)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Mostrar no Finder")
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
