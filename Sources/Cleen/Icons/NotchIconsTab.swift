import SwiftUI

/// The Ícones tab: search Lucide's icons and copy one as SVG, name or JSX.
struct NotchIconsTab: View {
    var body: some View {
        Text("Ícones")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
