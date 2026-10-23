import SwiftUI

/// The open quick note on Início: its first lines, read at a glance. A tap opens Notas
/// to keep writing.
struct NoteWidget: View {
    let size: HomeWidgetSize
    @Environment(NotesModel.self) private var notes
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .notes } label: {
            VStack(alignment: .leading, spacing: 5) {
                HomeWidgetLabel(title: "Nota", symbol: "note.text")
                let preview = notes.selected.preview
                if preview.isEmpty {
                    Text("Toque para escrever")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                } else {
                    Text(preview)
                        .font(.system(size: 11))
                        .lineSpacing(0.5)
                        .foregroundStyle(NotchStyle.secondary)
                        .lineLimit(size == .large ? 5 : 4)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 88, alignment: .topLeading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Abrir Notas")
    }
}
