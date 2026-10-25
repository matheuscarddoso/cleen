import SwiftUI

/// Shown when a pick should have been pasted but Cleen isn't allowed to type into other
/// apps: what's copied is still on the clipboard, and one button opens the switch.
struct PastePermissionBanner: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Copiado. Para colar sozinho, o Cleen precisa de Acessibilidade.")
                    .font(NotchStyle.bodyMedium)
                Text("Ative o Cleen em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade.")
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
            Spacer(minLength: 8)
            Button("Permitir") { PasteKeystroke.requestPermission() }
                .buttonStyle(.notchPrimary)
            NotchIconButton(symbol: "xmark", help: String(localized: "Fechar")) { state.pasteNeedsPermission = false }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background {
            RoundedRectangle(cornerRadius: NotchStyle.cardRadius, style: .continuous).fill(NotchStyle.background)
            RoundedRectangle(cornerRadius: NotchStyle.cardRadius, style: .continuous).fill(NotchStyle.selection)
        }
        .overlay { RoundedRectangle(cornerRadius: NotchStyle.cardRadius, style: .continuous).strokeBorder(NotchStyle.cardStroke) }
        // Granted in Ajustes do Sistema: the banner goes by itself.
        .task {
            while !Task.isCancelled, !PasteKeystroke.isAllowed {
                try? await Task.sleep(for: .seconds(1))
            }
            state.pasteNeedsPermission = false
        }
    }
}
