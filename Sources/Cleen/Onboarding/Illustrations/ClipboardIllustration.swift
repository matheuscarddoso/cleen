import SwiftUI

/// Three copies fanned out like cards in a hand: a snippet of text, a link, and a
/// screenshot, each in the style of the clipboard tab.
struct ClipboardIllustration: View {
    var body: some View {
        ZStack {
            card(kind: "Texto", symbol: "text.alignleft") {
                Text("Reunião movida para quinta, 15h. Levar os números do trimestre.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(2)
            }
            .rotationEffect(.degrees(-11), anchor: .bottom)
            .offset(x: -88, y: 22)

            card(kind: "Link", symbol: "link") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("github.com").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    Text("cleen / pull / 42").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .rotationEffect(.degrees(1), anchor: .bottom)
            .offset(x: 10, y: -6)

            card(kind: "Imagem", symbol: "photo") {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [PaintPalette.night.glow, PaintPalette.night.haze], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { Image(systemName: "camera.viewfinder").font(.system(size: 22)).foregroundStyle(.white.opacity(0.7)) }
            }
            .rotationEffect(.degrees(12), anchor: .bottom)
            .offset(x: 96, y: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card<Content: View>(kind: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind, systemImage: symbol)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(width: 150, height: 180)
        .background(Color(white: 0.09).opacity(0.94), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12)) }
        .shadow(color: .black.opacity(0.4), radius: 22, y: 14)
    }
}
