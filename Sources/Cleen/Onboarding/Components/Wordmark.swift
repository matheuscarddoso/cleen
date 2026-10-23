import SwiftUI

/// "Cleen" set large, each letter arriving out of a blur a beat after the last, then a
/// soft band of light crossing it once.
struct Wordmark: View {
    let text: String
    let isShown: Bool
    @State private var sweep = false

    var body: some View {
        letters
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 90)
                    .offset(x: sweep ? 220 : -220)
                    .blendMode(.plusLighter)
                    .mask(letters)
                    .allowsHitTesting(false)
            }
            .onChange(of: isShown) { _, shown in
                guard shown else { return }
                withAnimation(.easeInOut(duration: 1.3).delay(0.7)) { sweep = true }
            }
            .accessibilityElement()
            .accessibilityLabel(text)
    }

    private var letters: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .opacity(isShown ? 1 : 0)
                    .blur(radius: isShown ? 0 : 12)
                    .offset(y: isShown ? 0 : 20)
                    .animation(.smooth(duration: 0.95).delay(Double(index) * 0.08), value: isShown)
            }
        }
        .font(.system(size: 96, weight: .semibold))
        .tracking(-3.5)
        .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.78)], startPoint: .top, endPoint: .bottom))
    }
}
