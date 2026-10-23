import SwiftUI

/// Ajustes › Telas: a brightness slider for every screen, the external monitor's too.
struct DisplaySettings: View {
    @Environment(DisplaysModel.self) private var displays

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotchGroup {
                if displays.items.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Lendo as telas…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    ForEach(displays.items) { item in
                        row(item)
                    }
                }
            }
            Text("O monitor externo recebe o brilho pelo próprio cabo, como nos botões dele. Se ele não aceitar, o Cleen escurece a imagem.")
                .font(.system(size: 10))
                .foregroundStyle(NotchStyle.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .task { await displays.load() }
    }

    private func row(_ item: DisplaysModel.Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.control == .builtIn ? "laptopcomputer" : "display")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.control == .builtIn ? String(localized: "Tela do Mac") : item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(note(for: item.control))
                    .font(.system(size: 10))
                    .foregroundStyle(NotchStyle.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            BrightnessSlider(value: item.brightness, minimum: item.control == .dimming ? ScreenDimming.minimum : 0) { level in
                displays.setBrightness(level, for: item.id)
            }
            .frame(width: 200)
            Text(item.brightness.percent)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(NotchStyle.secondary)
                .contentTransition(.numericText())
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
    }

    private func note(for control: DisplaysModel.Item.Control) -> String {
        switch control {
        case .builtIn: String(localized: "Igual às teclas de brilho")
        case .cable: String(localized: "Pelo cabo, direto no monitor")
        case .dimming: String(localized: "Sem ajuste pelo cabo · escurece a imagem")
        }
    }
}
