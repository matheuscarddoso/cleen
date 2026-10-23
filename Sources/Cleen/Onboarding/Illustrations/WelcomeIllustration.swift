import SwiftUI

/// A Mac's screen with Cleen open in its notch, exactly as Início looks.
struct WelcomeIllustration: View {
    var body: some View {
        MacScreen {
            NotchPanelMock()
                .shadow(color: .black.opacity(0.4), radius: 30, y: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
