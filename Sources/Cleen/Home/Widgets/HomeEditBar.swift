import SwiftUI

/// Above the widgets while Início is being edited: the greeting switch and every widget
/// that isn't there yet, one tap to add.
struct HomeEditBar: View {
    @Environment(HomeLayout.self) private var layout

    var body: some View {
        @Bindable var layout = layout
        HStack(spacing: 6) {
            chip(layout.showsGreeting ? "checkmark" : "plus", "Saudação", isOn: layout.showsGreeting) {
                withAnimation(.smooth(duration: 0.3)) { layout.showsGreeting.toggle() }
            }
            Rectangle()
                .fill(NotchStyle.separator)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 2)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(layout.available) { kind in
                        chip(kind.symbol, kind.title, isOn: false) {
                            withAnimation(.smooth(duration: 0.3)) { layout.add(kind) }
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                    if layout.available.isEmpty {
                        Text("Todos os widgets estão no Início")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchStyle.tertiary)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollEdgeFade(.horizontal, length: 14)
            Button("Restaurar") {
                withAnimation(.smooth(duration: 0.3)) { layout.reset() }
            }
            .buttonStyle(.notchSecondary)
        }
        .frame(height: 26)
    }

    private func chip(_ symbol: String, _ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isOn ? .black : NotchStyle.primary.opacity(0.85))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(isOn ? Color.white : NotchStyle.control, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(isOn ? "Esconder \(title.lowercased())" : "Adicionar \(title.lowercased())")
    }
}
