import SwiftUI

/// The round swap button between the boxes; the arrows turn half a circle each time.
struct ConverterSwapButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var turns = 0.0

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { turns += 0.5 }
            action()
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovered ? NotchStyle.primary : NotchStyle.secondary)
                .rotationEffect(.degrees(turns * 360))
                .frame(width: 30, height: 30)
                .background(isHovered ? NotchStyle.controlHover : NotchStyle.control, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.15)) { isHovered = hovering }
        }
        .help("Inverter unidades")
        .accessibilityLabel("Inverter unidades")
    }
}
