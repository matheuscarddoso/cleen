import SwiftUI

/// The button on anything that deletes. It doesn't delete: it opens the review (the
/// notch grows and lists what's about to go, with Cancelar and Confirmar), and only
/// Confirmar there runs `action`.
struct ConfirmingButton: View {
    let title: String
    var isWorking = false
    /// What's about to go, read when the button is clicked (the selection then).
    let items: () -> [DeletionReview.Item]
    var outcome = DeletionReview.Outcome.trash
    let action: () -> Void

    @Environment(NotchState.self) private var notch

    var body: some View {
        Button {
            let items = items()
            guard !items.isEmpty else { return }
            notch.review(DeletionReview(
                title: DeletionReview.title(count: items.count, outcome: outcome),
                items: items,
                outcome: outcome,
                confirm: action
            ))
        } label: {
            HStack(spacing: 6) {
                if isWorking {
                    ProgressView().controlSize(.mini).tint(.black)
                }
                Text(title)
            }
        }
        .buttonStyle(.notchPrimary)
        .disabled(isWorking)
    }
}
