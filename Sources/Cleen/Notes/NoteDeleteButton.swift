import SwiftUI

/// `ConfirmingButton`'s two taps, sized for the note header: a trash glyph that turns
/// into a red "Apagar nota" pill, then deletes. A blank note goes on the first tap;
/// there's nothing to lose.
struct NoteDeleteButton: View {
    /// The note it would delete; switching notes disarms it.
    let noteID: UUID
    let isBlank: Bool
    let isOnlyNote: Bool
    let action: () -> Void

    @Environment(NotchState.self) private var notch
    @State private var isArmed = false
    @State private var isHovered = false
    @State private var disarm: Task<Void, Never>?
    /// What the panel's hold was before arming, so disarming gives it back.
    @State private var heldBefore = false

    var body: some View {
        Button(action: tap) {
            Group {
                if isArmed {
                    Text("Apagar nota")
                        .font(NotchStyle.captionMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(NotchStyle.critical, in: .capsule)
                        .transition(.scale(scale: 0.9, anchor: .trailing).combined(with: .opacity))
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isHovered ? NotchStyle.critical : NotchStyle.secondary)
                        .frame(width: 26, height: 24)
                        .background(isHovered ? NotchStyle.control : .clear, in: .rect(cornerRadius: 7))
                        .transition(.opacity)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .help(isArmed ? "Clique de novo para apagar" : "Apagar nota")
        .accessibilityLabel(isArmed ? "Confirmar: apagar nota" : "Apagar nota")
        .animation(.smooth(duration: 0.18), value: isArmed)
        .animation(.smooth(duration: 0.15), value: isHovered)
        .onChange(of: noteID) { reset() }
        .onDisappear(perform: reset)
    }

    /// A single blank note has nothing to delete.
    private var isDisabled: Bool { isOnlyNote && isBlank }

    private func tap() {
        if isArmed || isBlank {
            reset()
            action()
            return
        }
        heldBefore = notch.holdsOpen
        isArmed = true
        notch.holdsOpen = true
        disarm = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    private func reset() {
        disarm?.cancel()
        disarm = nil
        guard isArmed else { return }
        isArmed = false
        notch.holdsOpen = heldBefore
    }
}
