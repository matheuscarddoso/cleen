import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        OnboardingPage(
            title: greeting,
            message: "O Cleen mora no notch do seu Mac. Ele deixa o disco leve e o seu dia a um gesto de distância.",
            primary: "Começar",
            footnote: "Seus arquivos são analisados aqui mesmo e nunca saem do Mac."
        ) {
            VStack(alignment: .leading, spacing: 6) {
                OnboardingRow(symbol: "sparkles", title: "Limpeza em um clique", note: "Caches, restos de apps e projetos parados")
                OnboardingRow(symbol: "calendar", title: "Seu dia no notch", note: "Agenda, música e o Espelho antes da chamada")
                OnboardingRow(symbol: "doc.on.clipboard", title: "Tudo o que você copiou", note: "Histórico da área de transferência e screenshots")
            }
        }
    }

    /// The first name when macOS knows it, so the first words are personal.
    private var greeting: String {
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Boas-vindas ao Cleen" : "Boas-vindas, \(first)"
    }
}
