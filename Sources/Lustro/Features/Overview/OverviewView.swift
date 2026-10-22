import LustroKit
import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var app
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    OverviewHero(confirmClean: confirm)
                    if app.isSmartScanning || app.hasSmartResults {
                        FindingsGrid()
                    }
                    VitalsStrip()
                }
                .padding(32)
            }
        }
        .confirmationDialog("Limpar \(app.smartCleanSize.bytes)?", isPresented: $confirming) {
            Button("Limpar", action: clean)
        } message: {
            Text("Caches, logs e dependências de projetos parados são apagados de vez; tudo isso volta sozinho ou com um install. Instaladores vão para o Lixo. Para escolher item por item, abra cada seção.")
        }
    }

    private func confirm() {
        confirming = true
    }

    private func clean() {
        Task { await app.smartClean() }
    }
}
