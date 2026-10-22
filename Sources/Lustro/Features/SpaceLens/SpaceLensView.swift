import AppKit
import LustroKit
import SwiftUI

struct SpaceLensView: View {
    @Environment(SpaceLensModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Mapa do disco", subtitle: subtitle) {
                SpaceTargetMenu()
            }
            switch model.phase {
            case .idle:
                ScanPrompt(
                    symbol: "chart.pie",
                    title: "Onde está o seu espaço",
                    message: "Mede cada pasta e mostra o tamanho de tudo, para você descer até o que pesa. Comece pela sua pasta pessoal ou pelo disco inteiro.",
                    buttonTitle: "Mapear minha pasta",
                    action: scanHome
                )
            case .scanning:
                ScanningView(title: "Medindo \(model.target.title.lowercased())", detail: progressText, cancel: model.cancel)
            case .ready:
                if let current = model.current {
                    SpaceExplorer(node: current)
                } else {
                    AllClearView(title: "Não foi possível ler", message: "Essa pasta não pôde ser aberta.", rescan: scanHome)
                }
            }
        }
    }

    private var subtitle: String {
        if model.phase == .ready, let root = model.root {
            var text = "\(model.target.title) · \(root.size.bytes)"
            if model.unreadable > 0 {
                text += " · \(model.unreadable) pastas sem acesso"
            }
            return text
        }
        return "Cada pasta medida, da maior para a menor."
    }

    private var progressText: String {
        guard let progress = model.progress else { return "" }
        return "\(progress.items.counted) itens · \(progress.bytes.bytes)"
    }

    private func scanHome() {
        model.scan(.home)
    }
}
