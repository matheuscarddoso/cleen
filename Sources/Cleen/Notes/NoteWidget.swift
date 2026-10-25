import SwiftUI

/// The open quick note on Início, written right there: the same Markdown editor as
/// Notas, smaller. The label opens Notas for the other notes.
struct NoteWidget: View {
    let size: HomeWidgetSize
    @Environment(NotesModel.self) private var notes
    @Environment(NotchState.self) private var state
    /// The panel is kept open because the person is writing here.
    @State private var holdsForTyping = false
    @State private var isFocused = false

    var body: some View {
        let text = Binding(get: { notes.text }, set: { newValue in
            notes.text = newValue
            holdWhileTyping()
        })
        VStack(alignment: .leading, spacing: 5) {
            Button { state.tab = .notes } label: {
                HomeWidgetLabel(title: String(localized: "Nota"), symbol: "note.text")
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Abrir Notas")
            ZStack(alignment: .topLeading) {
                NoteEditor(text: text, baseSize: 11.5) { focused in
                    isFocused = focused
                    if !focused { releaseHold() }
                }
                if notes.selected.text.isEmpty {
                    Text("Escreva aqui")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 88, alignment: .topLeading)
        .onDisappear(perform: releaseHold)
    }

    /// Writing keeps the panel open even if the pointer drifts off it.
    private func holdWhileTyping() {
        guard isFocused, !holdsForTyping else { return }
        holdsForTyping = true
        state.holdsOpen = true
    }

    private func releaseHold() {
        guard holdsForTyping else { return }
        holdsForTyping = false
        state.holdsOpen = false
    }
}
