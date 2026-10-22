import CleenKit
import SwiftUI

struct StartupView: View {
    @Environment(StartupModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Inicialização", subtitle: subtitle) {
                Button("Itens de início do macOS", action: openLoginItems)
                    .buttonStyle(.quiet)
                Button("Atualizar", action: refresh)
                    .buttonStyle(.quiet)
                    .disabled(model.phase == .scanning)
            }
            if model.phase == .ready {
                StartupList()
            } else {
                ScanningView(title: "Lendo o que abre sozinho", detail: "")
            }
        }
        .task { if model.phase == .idle { await model.scan() } }
    }

    private var subtitle: String {
        guard model.phase == .ready else { return "Agentes e serviços que o macOS inicia sem você pedir." }
        let suspicious = model.suspicious.count
        let base = "\(model.items.count) itens abrem sozinhos"
        return suspicious == 0 ? base + " · todos assinados" : base + " · \(suspicious) sem assinatura confiável"
    }

    private func refresh() {
        Task { await model.scan() }
    }

    private func openLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            openURL(url)
        }
    }
}
