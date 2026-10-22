import SwiftUI

struct AgendaAccessLink: View {
    let text: String

    var body: some View {
        Button(text, action: AgendaModel.openPrivacySettings)
            .buttonStyle(.plain)
            .font(NotchStyle.caption)
            .foregroundStyle(NotchStyle.warning)
    }
}
