import SwiftUI

/// Which tools Uso de IA (and its Início widget) shows, with whether each was found here.
struct AIUsageSettings: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        NotchGroup {
            ForEach(AITool.allCases) { tool in
                SettingRow(title: tool.name, note: note(for: tool)) {
                    NotchSwitch(label: tool.name, isOn: Binding(get: { model.shows(tool) }, set: { model.setShows(tool, $0) }))
                }
            }
        }
        .task { await model.refresh(force: true) }
    }

    private func note(for tool: AITool) -> String {
        guard model.shows(tool) else { return String(localized: "Escondido") }
        return model.isFound(tool) ? String(localized: "Encontrado neste Mac") : String(localized: "Não encontrado neste Mac")
    }
}
