import CleenKit
import SwiftUI

struct StartupList: View {
    @Environment(StartupModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(Theme.body)
                        .foregroundStyle(Theme.warning)
                        .surface(radius: Theme.Radius.medium, padding: 12)
                }
                if !model.suspicious.isEmpty {
                    Text("Sem assinatura não quer dizer malicioso, mas ninguém responde por esses itens. Se você não reconhece um deles, desative: dá para reativar a qualquer momento.")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                        .surface(radius: Theme.Radius.medium, padding: 14)
                }
                ForEach(LaunchItem.Scope.allCases, id: \.self) { scope in
                    let items = model.items(in: scope)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: scope.rawValue, trailing: scope.needsAdministrator ? "pede senha para mudar" : nil)
                            VStack(spacing: 0) {
                                ForEach(items) { item in
                                    LaunchItemRow(item: item)
                                    if item.id != items.last?.id {
                                        Divider().overlay(Theme.hairline).padding(.leading, 58)
                                    }
                                }
                            }
                            .surface(padding: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
