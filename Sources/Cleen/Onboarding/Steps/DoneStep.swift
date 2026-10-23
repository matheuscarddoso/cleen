import EventKit
import SwiftUI

struct DoneStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        OnboardingPage(
            title: "Tudo pronto",
            message: "O Cleen já está no notch. Quando quiser, é só passar o ponteiro por lá.",
            primary: "Abrir o Cleen",
            footnote: "Tudo isso dá para mudar em Ajustes, no próprio notch.",
            onPrimary: model.finish
        ) {
            VStack(alignment: .leading, spacing: 8) {
                summary("Acesso Total ao Disco", on: model.fullDiskAccess)
                summary("Calendário e Lembretes", on: EKEventStore.authorizationStatus(for: .event) == .fullAccess)
                summary("Colar com um clique", on: model.accessibility)
                summary(tabs.visible.count.counted("aba no notch", "abas no notch"), on: true)
            }
        }
    }

    private func summary(_ title: String, on: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 13))
                .foregroundStyle(on ? NotchStyle.good : NotchStyle.tertiary)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(on ? NotchStyle.primary.opacity(0.85) : NotchStyle.tertiary)
            if !on {
                Text("depois")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.tertiary)
            }
        }
    }
}
