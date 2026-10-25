import AppKit
import CleenKit
import SwiftUI

/// Ajustes › Notas: where the quick notes also live. Obsidian syncs both ways through a
/// "Cleen" folder in the vault; the Notes app gets a copy of each note.
struct NotesSettings: View {
    @Environment(NotesSync.self) private var sync
    @Environment(NotchState.self) private var notch
    /// The vaults Obsidian has open or opened, newest first.
    @State private var vaults: [ObsidianVaults.Vault] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchGroup {
                SettingRow(title: String(localized: "Sincronizar com"), note: targetNote) {
                    NotchSegmented(options: NotesSync.Target.allCases.map { ($0.title, $0) }, selection: Binding(get: { sync.target }, set: { choose($0) }))
                }
                if sync.target != .none {
                    SettingRow(title: String(localized: "Estado"), note: statusText) {
                        Button("Sincronizar agora") { sync.syncNow() }
                            .buttonStyle(.notchSecondary)
                            .disabled(sync.status == .syncing)
                    }
                }
            }
            if sync.target == .obsidian {
                Text("COFRE")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(NotchStyle.tertiary)
                    .padding(.leading, 4)
                NotchGroup {
                    ForEach(vaults) { vault in
                        vaultRow(name: vault.name, path: vault.path)
                    }
                    if let vault = sync.vault, !vaults.contains(where: { $0.path == vault.path(percentEncoded: false) }) {
                        vaultRow(name: vault.lastPathComponent, path: vault.path(percentEncoded: false))
                    }
                    SettingRow(title: String(localized: "Outra pasta…")) {
                        NotchIconButton(symbol: "folder", help: String(localized: "Escolher a pasta do cofre"), action: pickFolder)
                    }
                }
            }
        }
        .onAppear { vaults = ObsidianVaults.list() }
    }

    private func vaultRow(name: String, path: String) -> some View {
        let isChosen = sync.vault?.path(percentEncoded: false) == path
        return Button {
            sync.setVault(URL(filePath: path, directoryHint: .isDirectory))
        } label: {
            SettingRow(title: name, note: Paths.abbreviate(URL(filePath: path))) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isChosen ? NotchStyle.primary : NotchStyle.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// Obsidian with no vault picked yet takes the one opened last.
    private func choose(_ target: NotesSync.Target) {
        sync.setTarget(target)
        if target == .obsidian, sync.vault == nil, let newest = vaults.first {
            sync.setVault(URL(filePath: newest.path, directoryHint: .isDirectory))
        }
    }

    private var targetNote: String {
        switch sync.target {
        case .none:
            return String(localized: "As notas ficam só no Cleen.")
        case .obsidian:
            guard let vault = sync.vault else { return String(localized: "Escolha o cofre abaixo.") }
            let place = vault.lastPathComponent + "/" + NotesSync.folderName
            return String(localized: "Cada nota é um arquivo em \(place). Editar, criar ou apagar lá muda aqui também.")
        case .appleNotes:
            return String(localized: "Cada nota aparece na pasta Cleen do app Notas. O que você edita lá não volta para cá: o Notas só devolve o texto sem formatação.")
        }
    }

    private var statusText: String {
        switch sync.status {
        case .idle: String(localized: "Ainda não sincronizou.")
        case .syncing: String(localized: "Sincronizando…")
        case .synced(let date): String(localized: "Sincronizado \(date.formatted(.relative(presentation: .named)))")
        case .failed(let message): message
        case .notAllowed: String(localized: "Permita o Cleen controlar o Notas em Ajustes do Sistema › Privacidade e Segurança › Automação.")
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = String(localized: "Escolher")
        panel.message = String(localized: "Escolha a pasta do seu cofre do Obsidian.")
        notch.holdsOpen = true
        NSApp.activate()
        defer { notch.holdsOpen = false }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        sync.setVault(url)
    }
}
