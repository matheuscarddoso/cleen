import SwiftUI

struct ShortcutStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingPage(
            title: "Abra de qualquer lugar",
            message: "Leve o ponteiro até o notch, ou chame o Cleen pelo teclado, de dentro de qualquer app.",
            primary: "Continuar"
        ) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingRow(symbol: "cursorarrow.motionlines", title: "Passe o ponteiro no notch", note: "Ele abre sozinho e fecha quando você sai")
                OnboardingRow(symbol: "command", title: "Aperte ⌃⌥C", note: "Abre e fecha o notch onde estiver o ponteiro")
                HStack(spacing: 8) {
                    Image(systemName: model.triedShortcut ? "checkmark.circle.fill" : "keyboard")
                        .foregroundStyle(model.triedShortcut ? NotchStyle.good : NotchStyle.tertiary)
                        .contentTransition(.symbolEffect(.replace))
                    Text(model.triedShortcut ? "Isso. É assim que você chama o Cleen." : "Experimente agora: ⌃ Control, ⌥ Option e C.")
                        .foregroundStyle(model.triedShortcut ? NotchStyle.good : NotchStyle.tertiary)
                        .contentTransition(.opacity)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 10)
            }
        }
    }
}
