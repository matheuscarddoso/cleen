import SwiftUI

struct ClipboardStep: View {
    @Environment(OnboardingModel.self) private var model
    @AppStorage(ClipboardModel.enabledKey) private var history = true
    @AppStorage(ScreenshotModel.opensNotchKey) private var screenshotOpens = true
    @AppStorage(ScreenshotModel.copiesOnCaptureKey) private var copiesOnCapture = false

    var body: some View {
        OnboardingPage(
            title: "O que você copia, guardado",
            message: "O Cleen lembra o que passou pela área de transferência e abre cada screenshot no notch, com as ações à mão.",
            primary: "Continuar",
            footnote: "Senhas de gerenciadores nunca entram no histórico."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingRow(symbol: "doc.on.clipboard", title: "Histórico da área de transferência") {
                    NotchSwitch(label: "Histórico", isOn: $history)
                }
                OnboardingRow(symbol: "camera.viewfinder", title: "Abrir o notch a cada screenshot") {
                    NotchSwitch(label: "Screenshots", isOn: $screenshotOpens)
                }
                OnboardingRow(symbol: "square.on.square", title: "Copiar o screenshot ao tirar") {
                    NotchSwitch(label: "Copiar ao tirar", isOn: $copiesOnCapture)
                }
                OnboardingRow(symbol: "cursorarrow.click.2", title: "Colar com um clique", note: "O macOS pede Acessibilidade para isso") {
                    PermissionControl(granted: model.accessibility, action: model.requestAccessibility)
                }
            }
        }
    }
}
