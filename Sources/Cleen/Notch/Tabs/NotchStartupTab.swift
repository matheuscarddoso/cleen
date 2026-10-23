import CleenKit
import SwiftUI

/// What opens by itself, with a switch per item. Turning one off is reversible.
struct NotchStartupTab: View {
    @Environment(StartupModel.self) private var model

    var body: some View {
        if model.phase != .ready {
            NotchScanning(title: String(localized: "Lendo o que abre sozinho"), detail: "")
                .task { if model.phase == .idle { await model.scan() } }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: String(localized: "\(model.items.count) itens"), caption: caption) {
                    Button("Atualizar", action: refresh)
                        .buttonStyle(.notchSecondary)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.warning)
                }
                NotchScroll {
                    VStack(spacing: 0) {
                        ForEach(model.items) { item in
                            NotchRow(
                                title: item.displayName,
                                subtitle: "\(item.signature.title) · \(item.scope.title)",
                                subtitleColor: item.signature.isSuspicious ? NotchStyle.warning.opacity(0.9) : NotchStyle.tertiary
                            ) {
                                LaunchItemIcon(item: item)
                            } trailing: {
                                if model.busy.contains(item.id) {
                                    ProgressView().controlSize(.mini).tint(.white)
                                } else {
                                    LaunchItemSwitch(item: item)
                                        .id("\(item.id)-\(item.isDisabled)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var caption: String {
        let suspicious = model.suspicious.count
        return suspicious == 0 ? String(localized: "abrem sozinhos · todos confiáveis") : String(localized: "abrem sozinhos · \(suspicious) sem assinatura confiável")
    }

    private func refresh() {
        Task { await model.scan() }
    }
}
