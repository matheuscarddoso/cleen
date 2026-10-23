import SwiftUI

/// A Mac's screen with the notch closed, ⌃ ⌥ C as real keys below it that sink under
/// the person's fingers, and the notch opening when the shortcut lands.
struct ShortcutIllustration: View {
    @Environment(OnboardingModel.self) private var model
    @State private var cPressed = false

    var body: some View {
        VStack(spacing: 0) {
            MacScreen {
                ZStack(alignment: .top) {
                    if model.triedShortcut {
                        NotchPanelMock()
                            .shadow(color: .black.opacity(0.4), radius: 30, y: 16)
                            .transition(.scale(scale: 0.3, anchor: .top).combined(with: .opacity))
                    } else {
                        ClosedNotchMock()
                            .transition(.opacity)
                    }
                }
            }
            HStack(spacing: 10) {
                KeyCap(glyph: "⌃", caption: "control", width: 66, isPressed: model.heldModifiers.contains(.control))
                KeyCap(glyph: "⌥", caption: "option", width: 66, isPressed: model.heldModifiers.contains(.option))
                KeyCap(glyph: "C", width: 66, isPressed: cPressed)
            }
            .padding(.top, -40)
            // Right under the notch.
            .offset(x: MacScreen<EmptyView>.centerShift)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: model.triedShortcut)
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
