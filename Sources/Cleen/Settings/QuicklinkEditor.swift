import CleenKit
import SwiftUI

/// A quick link being written: its name, the keyword typed before the query, and the
/// address with `{query}` where the search goes.
struct QuicklinkEditor: View {
    @State var link: Quicklink
    let onSave: (Quicklink) -> Void
    let onCancel: () -> Void

    private var isValid: Bool {
        !link.name.trimmingCharacters(in: .whitespaces).isEmpty && link.url(for: link.takesQuery ? "teste" : "") != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                EditorField(placeholder: String(localized: "Nome"), text: $link.name)
                EditorField(placeholder: String(localized: "Palavra-chave"), text: $link.keyword)
                    .frame(width: 110)
            }
            EditorField(placeholder: "https://exemplo.com/busca?q={query}", text: $link.url)
            Text("Onde entra o que você digita, escreva {query}. Na busca: palavra-chave, espaço e o termo.")
                .font(.system(size: 10))
                .foregroundStyle(NotchStyle.tertiary)
            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                    .buttonStyle(.notchSecondary)
                Button("Salvar") { onSave(link) }
                    .buttonStyle(.notchPrimary)
                    .disabled(!isValid)
            }
        }
        .padding(12)
    }
}
