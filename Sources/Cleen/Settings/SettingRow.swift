import SwiftUI

/// One line of a settings group: a label (and optional note) with its control on the right.
struct SettingRow<Control: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if let note {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(NotchStyle.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 36)
    }
}
