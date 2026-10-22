import AppKit
import CleenKit
import SwiftUI

struct CleaningSettings: View {
    @Environment(ProjectsModel.self) private var projects
    @Environment(NotchState.self) private var notch
    @AppStorage(ProjectsModel.staleDaysKey) private var staleDays = 30
    @AppStorage(LargeFilesModel.minimumKey) private var largeFileMinimum = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchGroup {
                SettingRow(title: "Projeto parado depois de", note: "Dependências desses projetos já vêm marcadas.") {
                    NotchStepper(value: $staleDays, range: 7...365, step: 7) { "\($0) dias" }
                }
                SettingRow(title: "Arquivo grande a partir de") {
                    NotchChoiceStepper(choices: [25, 50, 100, 250, 500, 1000], selection: $largeFileMinimum) { Int64($0 * 1_000_000).bytes }
                }
            }
            Text("PASTAS DE PROJETOS")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(NotchStyle.tertiary)
                .padding(.leading, 4)
            NotchGroup {
                ForEach(projects.roots, id: \.self) { root in
                    SettingRow(title: Paths.abbreviate(root)) {
                        if projects.isCustomRoot(root) {
                            NotchIconButton(symbol: "minus.circle", help: "Remover") { projects.removeRoot(root) }
                        } else {
                            Text("Padrão")
                                .font(.system(size: 10))
                                .foregroundStyle(NotchStyle.tertiary)
                        }
                    }
                }
                SettingRow(title: "Adicionar pasta…") {
                    NotchIconButton(symbol: "plus.circle", help: "Adicionar pasta", action: addFolder)
                }
            }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Adicionar"
        panel.message = "Escolha uma pasta com projetos de código."
        notch.holdsOpen = true
        NSApp.activate()
        defer { notch.holdsOpen = false }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        projects.addRoot(url)
    }
}
