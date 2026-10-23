import CleenKit
import SwiftUI

/// The picked app: its total size with data, what it spread around, and the uninstall.
struct AppUninstallPane: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        if let app = model.selectedApp {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    FileIcon(url: app.url, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text("\(model.removalSize.bytes) com os dados")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    Spacer(minLength: 6)
                    if !app.isSystem {
                        ConfirmingButton(title: String(localized: "Desinstalar"), confirmTitle: String(localized: "Confirmar"), isWorking: model.isUninstalling, action: uninstall)
                    }
                }
                if app.isSystem {
                    Text("Faz parte do macOS e não pode ser removido.")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.warning)
                }
                if let report = model.report {
                    NotchReportLine(report: report)
                }
                if model.isLoadingLeftovers {
                    ProgressView().controlSize(.small).tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !model.leftovers.isEmpty {
                    NotchScroll {
                        NotchGroup {
                            ForEach(model.leftovers) { leftover in
                                NotchRow(title: leftover.place.title, subtitle: Paths.abbreviate(leftover.url), verticalPadding: 3, action: { model.toggle(leftover) }) {
                                    NotchCheckbox(state: model.leftoverSelection.contains(leftover.url) ? .on : .off, label: leftover.url.lastPathComponent) { model.toggle(leftover) }
                                } trailing: {
                                    Text(leftover.size.bytes)
                                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                                        .foregroundStyle(NotchStyle.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("Nada além do próprio app.")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.tertiary)
                }
            }
            .animation(.smooth(duration: 0.25), value: model.report)
        } else if let report = model.report {
            NotchReportLine(report: report)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "xmark.app")
                    .font(.system(size: 20))
                    .foregroundStyle(NotchStyle.tertiary)
                Text("Escolha um app")
                    .font(.system(size: 12.5, weight: .medium))
                Text("Você vê o tamanho real, contando caches e dados, antes de remover.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchStyle.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func uninstall() {
        Task { await model.uninstall() }
    }
}
