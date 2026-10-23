import SwiftUI

struct ClipboardStep: View {
    @Environment(OnboardingModel.self) private var model
    @AppStorage(ClipboardModel.enabledKey) private var history = true
    @AppStorage(ScreenshotModel.opensNotchKey) private var screenshotOpens = true
    @AppStorage(ScreenshotModel.copiesOnCaptureKey) private var copiesOnCapture = false

    var body: some View {
        OnboardingPage(
            title: String(localized: "O que você copia, guardado"),
            message: String(localized: "O Cleen lembra o que passou pela área de transferência e abre cada screenshot no notch, com as ações à mão."),
            primary: String(localized: "Continuar"),
            footnote: String(localized: "Senhas de gerenciadores nunca entram no histórico.")
        ) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingRow(symbol: "doc.on.clipboard", title: String(localized: "Histórico da área de transferência")) {
                    NotchSwitch(label: String(localized: "Histórico"), isOn: $history)
                }
                OnboardingRow(symbol: "camera.viewfinder", title: String(localized: "Abrir o notch a cada screenshot")) {
                    NotchSwitch(label: String(localized: "Screenshots"), isOn: $screenshotOpens)
                }
                OnboardingRow(symbol: "square.on.square", title: String(localized: "Copiar o screenshot ao tirar")) {
                    NotchSwitch(label: String(localized: "Copiar ao tirar"), isOn: $copiesOnCapture)
                }
                OnboardingRow(symbol: "cursorarrow.click.2", title: String(localized: "Colar com um clique"), note: String(localized: "O macOS pede Acessibilidade para isso")) {
                    PermissionControl(granted: model.accessibility, action: model.requestAccessibility)
                }
            }
        }
    }
}
