import SwiftUI

/// The Teleprompter tab: a script that scrolls right under the camera.
struct NotchTeleprompterTab: View {

    var body: some View {
        Text("Teleprompter")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
