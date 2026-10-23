import SwiftUI

struct AgendaAccessLink: View {
    let text: String
    var action: @MainActor () -> Void = AgendaModel.openPrivacySettings

    var body: some View {
        Button(text, action: action)
            .buttonStyle(.plain)
            .font(NotchStyle.caption)
            .foregroundStyle(NotchStyle.warning)
    }
}
