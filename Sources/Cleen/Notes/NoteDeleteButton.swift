import SwiftUI

/// The note header's trash glyph. A note with something in it goes through the
/// review (the notch grows, shows the note, Cancelar or Apagar); a blank one goes at
/// once, there's nothing to lose.
struct NoteDeleteButton: View {
    let noteID: UUID
    /// What the review calls it: the note's title or first words.
    let title: String
    let isBlank: Bool
    let isOnlyNote: Bool
    let action: () -> Void

    @Environment(NotchState.self) private var notch
    @State private var isHovered = false

    var body: some View {
        Button(action: tap) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? NotchStyle.critical : NotchStyle.secondary)
                .frame(width: 26, height: 24)
                .background(isHovered ? NotchStyle.control : .clear, in: .rect(cornerRadius: 7))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .help("Apagar nota")
        .accessibilityLabel("Apagar nota")
        .animation(.smooth(duration: 0.15), value: isHovered)
    }

    /// A single blank note has nothing to delete.
    private var isDisabled: Bool { isOnlyNote && isBlank }

    private func tap() {
        guard !isBlank else { return action() }
        notch.review(DeletionReview(
            title: String(localized: "Apagar esta nota?"),
            items: [DeletionReview.Item(id: noteID.uuidString, name: title, detail: String(localized: "Nota"), symbol: "note.text")],
            outcome: .delete,
            confirm: action
        ))
    }
}
