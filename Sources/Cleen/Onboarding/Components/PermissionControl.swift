import SwiftUI

/// The right side of a permission line: "Permitir" until it's granted, then a check.
struct PermissionControl: View {
    let granted: Bool
    var label = "Permitir"
    let action: () -> Void

    var body: some View {
        ZStack {
            if granted {
                Label("Ativado", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchStyle.good)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                Button(label, action: action)
                    .buttonStyle(.notchPrimary)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: granted)
    }
}
