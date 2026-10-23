import SwiftUI

/// The first notch after the tour, as NotchNook greets you: "hello" writing itself,
/// a line of welcome, and two ways in. Either one grows the shape straight into the
/// open panel on Início.
struct WelcomeNotch: View {
    let controller: NotchController
    @State private var progress = 0.0
    @State private var showsText = false
    @State private var showsButtons = false

    var body: some View {
        VStack(spacing: 0) {
            HelloLettering()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 92, height: 92 / HelloLettering.aspectRatio)
                .padding(.bottom, 8)
                .accessibilityLabel("hello")
            VStack(spacing: 2) {
                Text("Boas-vindas ao Cleen!")
                    .font(.system(size: 13, weight: .semibold))
                Text("Um jeito novo de usar o seu Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .modifier(Reveal(isShown: showsText))
            HStack(spacing: 8) {
                WelcomeButton(title: String(localized: "Começar agora"), symbol: "arrow.forward.circle.fill") {
                    controller.dismissWelcome(editing: false)
                }
                WelcomeButton(title: String(localized: "Personalizar"), symbol: "slider.horizontal.3") {
                    controller.dismissWelcome(editing: true)
                }
            }
            .padding(.top, 12)
            .modifier(Reveal(isShown: showsButtons))
        }
        .frame(maxWidth: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeInOut(duration: 1.5)) { progress = 1 }
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.smooth(duration: 0.5)) { showsText = true }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.smooth(duration: 0.5)) { showsButtons = true }
        }
    }
}

/// Fades and settles a line into place, sharpening as it arrives.
private struct Reveal: ViewModifier {
    let isShown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .blur(radius: isShown ? 0 : 4)
            .offset(y: isShown ? 0 : 4)
    }
}

/// NotchNook's blue pill: icon and label, a touch brighter on hover.
private struct WelcomeButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(ToolPalette.blue.opacity(isHovered ? 1 : 0.88), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1)
        .onHover { hovering in withAnimation(.smooth(duration: 0.15)) { isHovered = hovering } }
    }
}
