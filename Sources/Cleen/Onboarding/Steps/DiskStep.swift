import SwiftUI

struct DiskStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingPage(
            title: String(localized: "Deixe o Cleen ver o disco todo"),
            message: String(localized: "Para achar o que pesa na Lixeira, no Mail e dentro dos apps, o macOS pede Acesso Total ao Disco. Nada é apagado sem você confirmar."),
            primary: model.fullDiskAccess ? String(localized: "Continuar") : String(localized: "Abrir Ajustes"),
            secondary: model.fullDiskAccess ? nil : String(localized: "Agora não"),
            footnote: model.fullDiskAccess ? nil : String(localized: "Dá para fazer isso depois em Ajustes › Geral."),
            onPrimary: model.primary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                instruction(1, String(localized: "Clique em Abrir Ajustes"))
                instruction(2, String(localized: "Ative o Cleen na lista"))
                instruction(3, String(localized: "Volte para cá, o resto é com a gente"))
                status
                    .padding(.top, 6)
            }
        }
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 22, height: 22)
                .background(NotchStyle.card, in: .circle)
                .overlay { Circle().strokeBorder(NotchStyle.cardStroke) }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(model.fullDiskAccess ? NotchStyle.tertiary : NotchStyle.primary.opacity(0.85))
                .strikethrough(model.fullDiskAccess, color: NotchStyle.tertiary)
        }
    }

    private var status: some View {
        HStack(spacing: 8) {
            if model.fullDiskAccess {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NotchStyle.good)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                Text("Acesso concedido")
                    .foregroundStyle(NotchStyle.good)
            } else {
                ProgressView()
                    .controlSize(.mini)
                Text("Esperando o macOS…")
                    .foregroundStyle(NotchStyle.tertiary)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .frame(height: 18)
    }
}
