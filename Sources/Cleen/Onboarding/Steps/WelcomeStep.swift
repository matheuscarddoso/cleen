import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        OnboardingPage(
            title: greeting,
            message: String(localized: "O Cleen mora no notch do seu Mac. Ele deixa o disco leve e o seu dia a um gesto de distância."),
            primary: String(localized: "Começar"),
            footnote: String(localized: "Seus arquivos são analisados aqui mesmo e nunca saem do Mac.")
        ) {
            VStack(alignment: .leading, spacing: 6) {
                OnboardingRow(symbol: "asterisk", title: String(localized: "Limpeza em um clique"), note: String(localized: "Caches, restos de apps e projetos parados"))
                OnboardingRow(symbol: "calendar", title: String(localized: "Seu dia no notch"), note: String(localized: "Agenda, música e o Espelho antes da chamada"))
                OnboardingRow(symbol: "doc.on.clipboard", title: String(localized: "Tudo o que você copiou"), note: String(localized: "Histórico da área de transferência e screenshots"))
            }
        }
    }

    /// The first name when macOS knows it, so the first words are personal.
    private var greeting: String {
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? String(localized: "Boas-vindas ao Cleen") : String(localized: "Boas-vindas, \(first)")
    }
}
