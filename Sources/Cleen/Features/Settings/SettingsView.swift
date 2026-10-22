import CleenKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(MenuBarDisplay.storageKey) private var menuBarDisplay = MenuBarDisplay.freeSpace
    @AppStorage(LowDiskAlert.enabledKey) private var lowDiskAlert = true
    @AppStorage(LowDiskAlert.thresholdKey) private var lowDiskThreshold = 10
    @AppStorage(ProjectsModel.staleDaysKey) private var staleDays = 30
    @AppStorage(LargeFilesModel.minimumKey) private var largeFileMinimum = 50
    @AppStorage(NotchSettings.openOnHoverKey) private var notchOpensOnHover = true
    @AppStorage(NotchSettings.hoverDelayKey) private var notchHoverDelay = 0.12
    @AppStorage(NotchSettings.showsWingsKey) private var notchShowsWings = true
    @AppStorage(NotchSettings.allScreensKey) private var notchOnAllScreens = false

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var hasFullDiskAccess = FullDiskAccess.isGranted
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Ajustes", subtitle: "Como o Cleen se comporta.")
            Form {
                Section("Geral") {
                    Toggle("Abrir ao iniciar a sessão", isOn: $launchesAtLogin)
                    if let loginError {
                        Text(loginError).font(Theme.caption).foregroundStyle(Theme.warning)
                    }
                    Picker("Na barra de menus, mostrar", selection: $menuBarDisplay) {
                        ForEach(MenuBarDisplay.allCases) { display in
                            Text(display.title).tag(display)
                        }
                    }
                }
                Section {
                    Picker("Abrir o painel", selection: $notchOpensOnHover) {
                        Text("Ao passar o mouse").tag(true)
                        Text("Ao clicar").tag(false)
                    }
                    if notchOpensOnHover {
                        Picker("Atraso", selection: $notchHoverDelay) {
                            Text("Nenhum").tag(0.0)
                            Text("Curto").tag(0.12)
                            Text("Médio").tag(0.3)
                            Text("Longo").tag(0.6)
                        }
                    }
                    Toggle("Mostrar disco e espaço livre ao lado da câmera", isOn: $notchShowsWings)
                    Toggle("Mostrar o notch também em monitores externos", isOn: $notchOnAllScreens)
                    LabeledContent("Atalho para abrir e fechar", value: "⌃⌥C")
                } header: {
                    Text("Notch")
                } footer: {
                    Text("Em telas sem notch, o Cleen desenha um no topo, no centro. O atalho abre o notch da tela onde está o mouse.")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Avisos") {
                    Toggle("Avisar quando o disco estiver quase cheio", isOn: $lowDiskAlert)
                    Stepper("Avisar abaixo de \(lowDiskThreshold) GB livres", value: $lowDiskThreshold, in: 2...100, step: 1)
                        .disabled(!lowDiskAlert)
                }
                Section("Limpeza") {
                    Stepper("Projeto parado depois de \(staleDays) dias sem mudança", value: $staleDays, in: 7...365, step: 7)
                    Picker("Arquivo grande a partir de", selection: $largeFileMinimum) {
                        ForEach([25, 50, 100, 250, 500, 1000], id: \.self) { megabytes in
                            Text(Int64(megabytes * 1_000_000).bytes).tag(megabytes)
                        }
                    }
                }
                Section("Permissões") {
                    LabeledContent("Acesso Total ao Disco") {
                        HStack(spacing: 10) {
                            Text(hasFullDiskAccess ? "Concedido" : "Não concedido")
                                .foregroundStyle(hasFullDiskAccess ? Theme.good : Theme.warning)
                            if !hasFullDiskAccess {
                                Button("Abrir Ajustes do Sistema", action: openFullDiskAccess)
                            }
                        }
                    }
                    Text("Sem ele, o Cleen não enxerga a Lixeira, o Mail, o Safari e os containers de outros apps. Nada sai do seu Mac de qualquer jeito.")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
                Section("O que o Cleen nunca faz") {
                    PromiseRow(text: "Apagar de vez algo que você criou. Seus arquivos sempre vão para o Lixo.")
                    PromiseRow(text: "Mexer em pastas do sistema ou nas pastas principais da sua conta.")
                    PromiseRow(text: "Remover idiomas de dentro dos apps, o que quebra a assinatura deles.")
                    PromiseRow(text: "Mandar qualquer dado para fora do Mac. O Cleen não acessa a internet.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: launchesAtLogin) { _, enabled in
            updateLoginItem(enabled)
        }
        .onChange(of: lowDiskAlert) { _, enabled in
            if enabled { Task { await LowDiskAlert.requestPermission() } }
        }
        .task {
            hasFullDiskAccess = FullDiskAccess.isGranted
            if lowDiskAlert { await LowDiskAlert.requestPermission() }
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = "Não deu para mudar: \(error.localizedDescription)"
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func openFullDiskAccess() {
        openURL(FullDiskAccess.settingsURL)
    }
}
