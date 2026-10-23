import SwiftUI

/// Dims the desktop behind the tour, heavier at the top where the panel hangs.
struct OnboardingBackdrop: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        LinearGradient(colors: [.black.opacity(0.62), .black.opacity(0.38)], startPoint: .top, endPoint: .bottom)
            .opacity(model.phase == .titles || model.phase == .tour ? 1 : 0)
            .ignoresSafeArea()
    }
}
