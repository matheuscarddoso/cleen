import SwiftUI

/// A one-line field inside a settings group's inline editor.
struct EditorField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(NotchStyle.control, in: .rect(cornerRadius: 7, style: .continuous))
    }
}
