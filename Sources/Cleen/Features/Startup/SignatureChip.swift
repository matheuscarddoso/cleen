import CleenKit
import SwiftUI

/// Who vouches for a launch item, in one small pill.
struct SignatureChip: View {
    let signature: SignatureStatus

    var body: some View {
        Label(signature.title, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(Theme.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: .capsule)
            .lineLimit(1)
            .help(help)
    }

    private var symbol: String {
        switch signature {
        case .apple: "apple.logo"
        case .developer: "checkmark.seal"
        case .packageManager: "shippingbox"
        case .adHoc: "hammer"
        case .unsigned, .broken: "exclamationmark.triangle"
        case .script: "scroll"
        case .missing: "questionmark.circle"
        }
    }

    private var color: Color {
        switch signature {
        case .apple, .developer: Theme.good
        case .packageManager: .secondary
        case .unsigned, .broken, .script, .adHoc: Theme.warning
        case .missing: .secondary
        }
    }

    private var help: String {
        switch signature {
        case .apple: "Assinado pela Apple."
        case .developer(let team): "Assinado por \(team), desenvolvedor identificado pela Apple."
        case .unsigned: "O programa não tem assinatura. Ninguém responde por ele."
        case .packageManager(let name): "Instalado pelo \(name). Você mesmo o configurou para iniciar."
        case .adHoc: "Assinado neste Mac, sem certificado: comum em apps que você compilou. Não diz quem fez o programa."
        case .broken: "A assinatura não confere: o programa foi modificado depois de assinado."
        case .script: "Roda um script; a assinatura do interpretador não diz nada sobre o que ele faz."
        case .missing: "O programa que este item abriria não existe mais. É um resto seguro de remover."
        }
    }
}
