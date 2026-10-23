import SwiftUI

struct ShortcutStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingPage(
            title: String(localized: "Abra de qualquer lugar"),
            message: String(localized: "Leve o ponteiro até o notch, ou chame o Cleen pelo teclado, de dentro de qualquer app."),
            primary: String(localized: "Continuar")
        ) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingRow(symbol: "cursorarrow.motionlines", title: String(localized: "Passe o ponteiro no notch"), note: String(localized: "Ele abre sozinho e fecha quando você sai"))
                OnboardingRow(symbol: "command", title: String(localized: "Aperte ⌃⌥C"), note: String(localized: "Abre e fecha o notch onde estiver o ponteiro"))
                HStack(spacing: 8) {
                    Image(systemName: model.triedShortcut ? "checkmark.circle.fill" : "keyboard")
                        .foregroundStyle(model.triedShortcut ? NotchStyle.good : NotchStyle.tertiary)
                        .contentTransition(.symbolEffect(.replace))
                    Text(model.triedShortcut ? String(localized: "Isso. É assim que você chama o Cleen.") : String(localized: "Experimente agora: ⌃ Control, ⌥ Option e C."))
                        .foregroundStyle(model.triedShortcut ? NotchStyle.good : NotchStyle.tertiary)
                        .contentTransition(.opacity)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 10)
            }
        }
    }
}
