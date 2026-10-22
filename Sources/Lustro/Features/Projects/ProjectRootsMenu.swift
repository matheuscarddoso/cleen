import AppKit
import LustroKit
import SwiftUI

/// Which folders are searched for projects, and a way to add more.
struct ProjectRootsMenu: View {
    @Environment(ProjectsModel.self) private var model

    var body: some View {
        Menu("Pastas") {
            Section("Analisadas") {
                ForEach(model.roots, id: \.self) { root in
                    if model.isCustomRoot(root) {
                        Button("Remover \(Paths.abbreviate(root))") { model.removeRoot(root) }
                    } else {
                        Text(Paths.abbreviate(root))
                    }
                }
            }
            Divider()
            Button("Adicionar pasta…", action: chooseFolder)
        }
        .menuStyle(.button)
        .buttonStyle(.quiet)
        .fixedSize()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adicionar"
        panel.message = "Escolha uma pasta com projetos de código."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.addRoot(url)
    }
}
