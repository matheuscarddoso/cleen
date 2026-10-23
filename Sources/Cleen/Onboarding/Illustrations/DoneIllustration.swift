import SwiftUI

/// Cleen's icon, resting in the light of the painting behind it.
struct DoneIllustration: View {
    @State private var floats = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 150, height: 150)
            .shadow(color: .black.opacity(0.35), radius: 24, y: 16)
            .offset(y: floats ? -5 : 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { floats = true }
            }
    }
}
