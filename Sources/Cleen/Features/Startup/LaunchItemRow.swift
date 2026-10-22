import AppKit
import CleenKit
import SwiftUI

struct LaunchItemRow: View {
    @Environment(StartupModel.self) private var model
    let item: LaunchItem
    @State private var confirmingRemoval = false

    var body: some View {
        HStack(spacing: 14) {
            LaunchItemIcon(item: item)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.displayName)
                        .font(Theme.bodyMedium)
                        .lineLimit(1)
                    SignatureChip(signature: item.signature)
                }
                Text(item.label)
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Text(state)
                .font(Theme.caption)
                .foregroundStyle(item.isDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            if model.busy.contains(item.id) {
                ProgressView().controlSize(.small).frame(width: 88)
            } else {
                Button(item.isDisabled ? "Ativar" : "Desativar", action: toggle)
                    .buttonStyle(.bordered)
                    .fixedSize()
                    .frame(width: 88)
            }
            Menu {
                Button("Mostrar arquivo no Finder", action: revealPlist)
                if let program = item.program, FileManager.default.fileExists(atPath: program.path(percentEncoded: false)) {
                    Button("Mostrar programa no Finder") { NSWorkspace.shared.activateFileViewerSelecting([program]) }
                }
                Divider()
                Button("Remover…", role: .destructive, action: confirmRemoval)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Mais ações para \(item.displayName)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .opacity(item.isDisabled ? 0.6 : 1)
        .confirmationDialog("Remover \(item.displayName)?", isPresented: $confirmingRemoval) {
            Button("Remover", role: .destructive, action: remove)
        } message: {
            Text("O serviço para e o arquivo dele vai para o Lixo. Se ele pertence a um app que você usa, o app pode recriá-lo. Desativar costuma ser a melhor escolha.")
        }
    }

    private var state: String {
        if item.isDisabled { return "Desativado" }
        if item.isLoaded { return item.keepsAlive ? "Sempre ativo" : "Ativo" }
        return item.runsAtLoad ? "Abre no login" : "Sob demanda"
    }

    private func toggle() {
        Task { await model.setEnabled(item.isDisabled, for: item) }
    }

    private func revealPlist() {
        NSWorkspace.shared.activateFileViewerSelecting([item.plist])
    }

    private func confirmRemoval() {
        confirmingRemoval = true
    }

    private func remove() {
        Task { await model.remove(item) }
    }
}
