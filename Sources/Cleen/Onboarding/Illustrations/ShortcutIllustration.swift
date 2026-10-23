import SwiftUI

/// ⌃ ⌥ C as real keys that sink under the person's fingers, and a little notch that
/// opens when the shortcut lands.
struct ShortcutIllustration: View {
    @Environment(OnboardingModel.self) private var model
    @State private var cPressed = false

    var body: some View {
        VStack(spacing: 48) {
            NotchShape(topRadius: model.triedShortcut ? 9 : 5, bottomRadius: model.triedShortcut ? 22 : 10)
                .fill(.black)
                .frame(width: model.triedShortcut ? 240 : 130, height: model.triedShortcut ? 92 : 26)
                .overlay {
                    if model.triedShortcut {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(NotchStyle.good)
                            .padding(.top, 8)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
                .frame(height: 92, alignment: .top)
            HStack(spacing: 14) {
                KeyCap(glyph: "⌃", caption: "control", isPressed: model.heldModifiers.contains(.control))
                KeyCap(glyph: "⌥", caption: "option", isPressed: model.heldModifiers.contains(.option))
                KeyCap(glyph: "C", isPressed: cPressed)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: model.triedShortcut)
        .onChange(of: model.shortcutPresses) {
            cPressed = true
            Task {
                try? await Task.sleep(for: .milliseconds(160))
                cPressed = false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
