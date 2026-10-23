import SwiftUI

/// The quick note on Início.
struct NoteWidget: View {
    let size: HomeWidgetSize

    var body: some View {
        Text("Nota")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
