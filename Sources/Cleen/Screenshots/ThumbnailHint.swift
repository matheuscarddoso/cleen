import SwiftUI

/// Explains the delay the native thumbnail causes and offers to turn it off.
struct ThumbnailHint: View {
    @Environment(ScreenshotModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.warning)
            Text("A miniatura do macOS segura o arquivo até sumir. Sem ela, o Cleen abre na hora.")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            Button("Desligar miniatura") { Task { await model.setNativeThumbnail(false) } }
                .buttonStyle(.notchSecondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(NotchStyle.card, in: .rect(cornerRadius: 9, style: .continuous))
    }
}
