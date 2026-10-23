import SwiftUI

/// The notch's tab bar, big: it follows the grid on the left as tools come and go,
/// and always fits its side of the panel.
struct TabsIllustration: View {
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        let visible = tabs.visible
        GeometryReader { proxy in
            // Icons shrink a little when many are on, so the bar never leaves the painting.
            let slot = min(34, (proxy.size.width - 56) / Double(max(visible.count, 1)))
            VStack(spacing: 16) {
                NotchShape(topRadius: 12, bottomRadius: 28)
                    .fill(.black)
                    .overlay { NotchShape(topRadius: 12, bottomRadius: 28).stroke(.white.opacity(0.14), lineWidth: 1) }
                    .frame(width: 48 + slot * Double(visible.count), height: 92)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 0) {
                            ForEach(Array(visible.enumerated()), id: \.element) { index, tab in
                                Image(systemName: tab.symbol)
                                    .font(.system(size: slot * 0.38, weight: .medium))
                                    .foregroundStyle(.white.opacity(index == 0 ? 1 : 0.55))
                                    .frame(width: slot - 2, height: slot - 4)
                                    .background(index == 0 ? NotchStyle.selection : .clear, in: .rect(cornerRadius: 8, style: .continuous))
                                    .frame(width: slot)
                                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                            }
                        }
                        .padding(.bottom, 14)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 26, y: 16)
                Text(visible.count.counted("ferramenta", "ferramentas"))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(.black.opacity(0.45), in: .capsule)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: visible)
    }
}
