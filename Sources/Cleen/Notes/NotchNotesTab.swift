import CleenKit
import SwiftUI

/// The Notas tab, as OmniNotch's quick note: a slim row of note chips over one large
/// plain-text card. Everything saves itself a moment after the last keystroke.
struct NotchNotesTab: View {
    @Environment(NotesModel.self) private var notes
    @Environment(NotchState.self) private var notch
    @State private var editorFocused = false
    @State private var focusRequest = 0
    /// The panel is kept open because the person is writing.
    @State private var holdsForTyping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NoteHeader(focusEditor: focusEditor)
            editor
        }
        .padding(.bottom, 2)
        // Focus once the tab has settled: making the editor first responder sets up the
        // text system and input method, which stalled the switch when done on its frame.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            focusEditor()
        }
        .onDisappear(perform: releaseHold)
    }

    private var editor: some View {
        let text = Binding(get: { notes.text }, set: { newValue in
            notes.text = newValue
            holdWhileTyping()
        })
        return ZStack(alignment: .topLeading) {
            NoteEditor(text: text, focusRequest: focusRequest) { focused in
                editorFocused = focused
                if !focused { releaseHold() }
            }
            if notes.selected.text.isEmpty {
                Text("Escreva algo… - lista, [] tarefa, # título")
                    .font(.system(size: 13))
                    .foregroundStyle(NotchStyle.tertiary)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // A click on the card's margin still lands in the note.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NotchStyle.card)
                .onTapGesture(perform: focusEditor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(editorFocused ? NotchStyle.primary.opacity(0.14) : NotchStyle.cardStroke)
                .allowsHitTesting(false)
        }
        .animation(.smooth(duration: 0.18), value: editorFocused)
        .animation(.smooth(duration: 0.12), value: notes.selected.text.isEmpty)
    }

    private func focusEditor() {
        focusRequest += 1
    }

    /// Writing keeps the panel open even if the pointer drifts off it, so the notch never
    /// folds up mid-sentence. A click elsewhere or Esc still closes it.
    private func holdWhileTyping() {
        guard editorFocused, !holdsForTyping else { return }
        holdsForTyping = true
        notch.holdsOpen = true
    }

    private func releaseHold() {
        guard holdsForTyping else { return }
        holdsForTyping = false
        notch.holdsOpen = false
    }
}

/// The chips that switch notes, a new-note button, and copy and delete for the open one.
private struct NoteHeader: View {
    @Environment(NotesModel.self) private var notes
    let focusEditor: () -> Void
    @State private var copied = false
    @State private var copyReset: Task<Void, Never>?

    var body: some View {
        let selected = notes.selected
        HStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 2) {
                        ForEach(notes.notebook.notes) { note in
                            NoteChip(title: note.title ?? String(localized: "Nova nota"), isSelected: note.id == selected.id) {
                                withAnimation(.smooth(duration: 0.2)) { notes.select(note) }
                                focusEditor()
                            }
                            .id(note.id)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                        NotchIconButton(symbol: "plus", help: notes.canAdd ? String(localized: "Nova nota") : String(localized: "Até \(QuickNotebook.limit) notas"), action: add)
                            .disabled(selected.isBlank || !notes.canAdd)
                            .opacity(selected.isBlank || !notes.canAdd ? 0.4 : 1)
                            .keyboardShortcut("n", modifiers: .command)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollEdgeFade(.horizontal, length: 16)
                .onChange(of: selected.id) { _, id in
                    withAnimation(.smooth(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }
            NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: copied ? String(localized: "Copiada") : String(localized: "Copiar nota"), isActive: copied) {
                copy(selected)
            }
            .contentTransition(.symbolEffect(.replace))
            .disabled(selected.isBlank)
            .opacity(selected.isBlank ? 0.4 : 1)
            NoteDeleteButton(noteID: selected.id, isBlank: selected.isBlank, isOnlyNote: notes.notebook.notes.count == 1) {
                withAnimation(.smooth(duration: 0.22)) { notes.delete(selected) }
                focusEditor()
            }
        }
        .frame(height: 24)
        .onDisappear { copyReset?.cancel() }
    }

    private func add() {
        withAnimation(.smooth(duration: 0.22)) { _ = notes.add() }
        focusEditor()
    }

    private func copy(_ note: QuickNote) {
        notes.copy(note)
        copied = true
        copyReset?.cancel()
        copyReset = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}

/// A note's name as a pill, in the same language as the clipboard's type pills.
private struct NoteChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 130)
                .foregroundStyle(isSelected || isHovered ? NotchStyle.primary : NotchStyle.secondary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(isSelected ? NotchStyle.selection : (isHovered ? NotchStyle.control : .clear), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .help(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
