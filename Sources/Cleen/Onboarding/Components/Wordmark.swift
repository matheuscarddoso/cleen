import SwiftUI

/// "Cleen" set large in brushed silver, each letter rising into place a beat after the
/// last, then a diagonal band of light crossing the letters once, like light catching
/// metal. The letters are one static mask; only the band moves, so it stays smooth.
struct Wordmark: View {
    let text: String
    let isShown: Bool
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        letters(fill: AnyShapeStyle(LinearGradient(
            colors: [Color(white: 0.96), Color(white: 0.72), Color(white: 0.84)],
            startPoint: .top, endPoint: .bottom
        )))
        .overlay { shine }
        .onChange(of: isShown) { _, shown in
            guard shown, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.1).delay(0.8)) { sweep = true }
        }
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    /// A soft white band, tilted, travelling from left of the word to past its end,
    /// seen only through the letters.
    private var shine: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.55), location: 0.38),
                    .init(color: .white, location: 0.5),
                    .init(color: .white.opacity(0.55), location: 0.62),
                    .init(color: .white.opacity(0), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: width * 0.5, height: proxy.size.height * 2)
            .rotationEffect(.degrees(20))
            .offset(x: sweep ? width * 0.95 : -width * 0.55, y: -proxy.size.height * 0.5)
        }
        .mask { letters(fill: AnyShapeStyle(.white)) }
        .allowsHitTesting(false)
    }

    private func letters(fill: AnyShapeStyle) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .opacity(isShown ? 1 : 0)
                    .offset(y: isShown || reduceMotion ? 0 : 22)
                    .animation(.spring(response: 0.7, dampingFraction: 0.86).delay(Double(index) * 0.07), value: isShown)
            }
        }
        .font(.system(size: 96, weight: .semibold))
        .tracking(-3.5)
        .foregroundStyle(fill)
    }
}
