import CleenKit
import SwiftUI

/// A snippet being written: its name, the keyword that expands it, and the text.
struct SnippetEditor: View {
    @State var snippet: Snippet
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    private var isValid: Bool {
        !snippet.name.trimmingCharacters(in: .whitespaces).isEmpty && !snippet.text.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                EditorField(placeholder: String(localized: "Nome"), text: $snippet.name)
                EditorField(placeholder: String(localized: ";palavra"), text: $snippet.keyword)
                    .frame(width: 110)
            }
            TextEditor(text: $snippet.text)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .padding(6)
                .frame(height: 72)
                .background(NotchStyle.control, in: .rect(cornerRadius: 7, style: .continuous))
            Text("Use {date}, {time}, {weekday} e {clipboard}; {cursor} marca onde o cursor fica.")
                .font(.system(size: 10))
                .foregroundStyle(NotchStyle.tertiary)
            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                    .buttonStyle(.notchSecondary)
                Button("Salvar") {
                    var saved = snippet
                    saved.keyword = saved.keyword.trimmingCharacters(in: .whitespaces)
                    // A lone ";" isn't a keyword: it'd expand on every semicolon.
                    if saved.keyword.count < 2 { saved.keyword = "" }
                    onSave(saved)
                }
                .buttonStyle(.notchPrimary)
                .disabled(!isValid)
            }
        }
        .padding(12)
    }
}
