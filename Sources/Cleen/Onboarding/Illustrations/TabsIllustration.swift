import SwiftUI

/// The notch on a Mac's screen, its tab bar following the grid on the left as tools
/// come and go.
struct TabsIllustration: View {
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        VStack(spacing: 0) {
            MacScreen {
                NotchPanelMock()
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 16)
            }
            Text(tabs.visible.count.counted("ferramenta", "ferramentas"))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .contentTransition(.numericText())
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(.black.opacity(0.45), in: .capsule)
                .padding(.top, -124)
                .offset(x: MacScreen<EmptyView>.centerShift)
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: tabs.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
