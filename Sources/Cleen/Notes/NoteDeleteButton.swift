import SwiftUI

/// The note header's trash glyph: one click deletes the note.
struct NoteDeleteButton: View {
    let isBlank: Bool
    let isOnlyNote: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
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
}
