import SwiftUI

/// Two taps instead of a dialog: the first arms it (it turns red and says what will
/// happen), the second does it. Dialogs don't belong in a panel that hides when you
/// look away. Disarms itself after a few seconds.
struct ConfirmingButton: View {
    let title: String
    let confirmTitle: String
    var isWorking = false
    let action: () -> Void

    @Environment(NotchState.self) private var notch
    @State private var isArmed = false
    @State private var disarm: Task<Void, Never>?

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 6) {
                if isWorking {
                    ProgressView().controlSize(.mini).tint(isArmed ? .white : .black)
                }
                Text(isArmed ? confirmTitle : title)
                    .contentTransition(.opacity)
            }
        }
        .buttonStyle(isArmed ? .notchDestructive : .notchPrimary)
        .disabled(isWorking)
        .animation(.smooth(duration: 0.18), value: isArmed)
        .onDisappear { reset() }
    }

    private func tap() {
        if isArmed {
            reset()
            action()
            return
        }
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
        isArmed = false
        notch.holdsOpen = false
    }
}
