import SwiftUI

/// The notch's scrolling list: fills the room the tool leaves, no indicators.
struct NotchScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeFade()
        .frame(maxHeight: .infinity)
    }
}
