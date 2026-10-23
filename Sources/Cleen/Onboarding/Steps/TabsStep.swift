import SwiftUI

struct TabsStep: View {
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        OnboardingPage(
            title: "Monte o seu notch",
            message: "Escolha as ferramentas da barra. A ordem e o resto ficam em Ajustes › Abas.",
            primary: "Continuar"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), alignment: .leading, spacing: 6) {
                ForEach(tabs.order) { tab in
                    TabChip(tab: tab, isOn: tabs.isVisible(tab)) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            tabs.setVisible(!tabs.isVisible(tab), for: tab)
                        }
                    }
                }
            }
        }
    }
}
