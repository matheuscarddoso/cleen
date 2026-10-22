import CleenKit
import SwiftUI

struct MaintenanceView: View {
    @Environment(MaintenanceModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Manutenção", subtitle: "Consertos pontuais com os comandos do próprio macOS. Use quando algo estiver estranho.")
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(MaintenanceTask.allCases) { task in
                        MaintenanceCard(task: task)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .task { await model.refresh() }
    }
}
