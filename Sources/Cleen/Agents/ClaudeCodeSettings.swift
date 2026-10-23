import AppKit
import CleenKit
import SwiftUI

/// Ajustes › Claude Code: the opt-in hook that brings permission requests to the notch.
/// Installing touches only Cleen's own entry in `~/.claude/settings.json`; removing takes
/// exactly that entry out again.
struct ClaudeCodeSettings: View {
    @Environment(AgentsModel.self) private var agents

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotchGroup {
                SettingRow(
                    title: String(localized: "Aprovar permissões pelo notch"),
                    note: String(localized: "Quando o Claude Code pedir permissão, o pedido aparece no notch. Com o Cleen fechado, ele pergunta no terminal, como sempre.")
                ) {
                    control
                }
                SettingRow(title: String(localized: "Ajustes do Claude Code"), note: Paths.abbreviate(ClaudeHookInstaller.standard.settings)) {
                    NotchIconButton(symbol: "folder", help: String(localized: "Mostrar no Finder"), action: reveal)
                        .disabled(agents.hookStatus == .claudeCodeMissing)
                }
            }
            if let message {
                Label {
                    Text(message.text)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: message.symbol)
                        .foregroundStyle(message.color)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(NotchStyle.secondary)
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: agents.hookStatus)
        .animation(.smooth(duration: 0.2), value: agents.hookProblem)
        .task { await agents.refreshHook() }
    }

    @ViewBuilder
    private var control: some View {
        HStack(spacing: 8) {
            if agents.isChangingHook {
                ProgressView().controlSize(.mini)
            }
            switch agents.hookStatus {
            case .installed:
                Button("Remover") { Task { await agents.removeHook() } }
                    .buttonStyle(.notchSecondary)
            case .incomplete:
                Button("Reinstalar") { Task { await agents.installHook() } }
                    .buttonStyle(.notchPrimary)
            case .notInstalled, .claudeCodeMissing, .unreadable:
                Button("Instalar") { Task { await agents.installHook() } }
                    .buttonStyle(.notchPrimary)
                    .disabled(agents.hookStatus == .claudeCodeMissing)
            }
        }
        .disabled(agents.isChangingHook)
    }

    private struct Message {
        let text: String
        let symbol: String
        let color: Color
    }

    /// What the person should know right now: a problem first, else the state.
    private var message: Message? {
        if let problem = agents.hookProblem {
            return Message(text: Self.text(for: problem), symbol: "exclamationmark.triangle.fill", color: NotchStyle.warning)
        }
        switch agents.hookStatus {
        case .installed:
            return Message(
                text: String(localized: "Ligado. O original ficou guardado em settings.json.cleen-backup."),
                symbol: "checkmark.circle.fill",
                color: NotchStyle.good
            )
        case .incomplete:
            return Message(text: String(localized: "O script do Cleen sumiu. Reinstale para voltar a funcionar."), symbol: "exclamationmark.triangle.fill", color: NotchStyle.warning)
        case .claudeCodeMissing:
            return Message(text: String(localized: "Claude Code não encontrado neste Mac."), symbol: "info.circle", color: NotchStyle.tertiary)
        case .unreadable(let failure):
            return Message(text: Self.text(for: failure), symbol: "exclamationmark.triangle.fill", color: NotchStyle.warning)
        case .notInstalled:
            return nil
        }
    }

    private static func text(for problem: AgentsModel.HookProblem) -> String {
        switch problem {
        case .install(let failure): text(for: failure)
        case .listen(.inUse): String(localized: "Outro Cleen já está recebendo os pedidos.")
        case .listen: String(localized: "Não deu para abrir a conexão local. Os pedidos continuam no terminal.")
        }
    }

    private static func text(for failure: ClaudeHookInstaller.Failure) -> String {
        switch failure {
        case .claudeCodeMissing:
            String(localized: "Claude Code não encontrado neste Mac.")
        case .malformed(let line):
            String(localized: "O settings.json tem um erro na linha \(line). O Cleen não mexe num arquivo que não consegue ler: corrija e tente de novo.")
        case .unexpectedShape(let path):
            String(localized: "No settings.json, \(path) está num formato que o Claude Code não espera. O Cleen não mexeu no arquivo.")
        case .changedWhileEditing:
            String(localized: "O settings.json mudou enquanto o Cleen editava. Tente de novo.")
        case .io(let detail):
            String(localized: "Não deu para salvar: \(detail)")
        }
    }

    private func reveal() {
        let settings = ClaudeHookInstaller.standard.settings
        if FileManager.default.fileExists(atPath: settings.path(percentEncoded: false)) {
            NSWorkspace.shared.activateFileViewerSelecting([settings])
        } else {
            NSWorkspace.shared.open(settings.deletingLastPathComponent())
        }
    }
}
