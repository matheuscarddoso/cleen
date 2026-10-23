import SwiftUI

/// The Emoji tab: search and copy or paste an emoji.
struct NotchEmojiTab: View {

    var body: some View {
        Text("Emoji")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
