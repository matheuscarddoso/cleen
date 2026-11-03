import SwiftUI

/// The primary pill on anything that deletes: one click runs `action` right away. While
/// the work runs it shows a spinner and can't be clicked again.
struct NotchActionButton: View {
    let title: String
    var isWorking = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
