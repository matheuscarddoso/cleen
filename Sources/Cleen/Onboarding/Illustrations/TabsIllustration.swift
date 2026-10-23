import SwiftUI

/// The notch on a Mac's screen, its tab bar following the grid on the left as tools
/// come and go.
struct TabsIllustration: View {
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        MacScreen {
            VStack(spacing: 28) {
                NotchPanelMock()
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 16)
                // Drawn in the screen's own points, like the panel above it.
                Text(tabs.visible.count.counted("ferramenta", "ferramentas"))
                    .font(.system(size: 24, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(.black.opacity(0.45), in: .capsule)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: tabs.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
