import AppKit
import SwiftUI

struct SpaceTargetMenu: View {
    @Environment(SpaceLensModel.self) private var model

    var body: some View {
        Menu("Mapear") {
            Button("Sua pasta pessoal") { model.scan(.home) }
            Button("Disco inteiro") { model.scan(.disk) }
            Divider()
            Button("Escolher pasta…", action: chooseFolder)
        }
        .menuStyle(.button)
        .buttonStyle(.quiet)
        .fixedSize()
        .disabled(model.phase == .scanning)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Mapear"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.scan(.folder(url))
    }
}
