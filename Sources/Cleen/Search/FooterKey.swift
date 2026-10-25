import SwiftUI

/// A hint in the launcher's bottom bar: what a key does, then the key itself.
struct FooterKey: View {
    let label: String
    let keys: [String]
    var emphasized = false

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(emphasized ? NotchStyle.primary : NotchStyle.secondary)
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                        .frame(minWidth: 20, minHeight: 20)
                        .padding(.horizontal, key.count > 1 ? 4 : 0)
                        .background(NotchStyle.control, in: .rect(cornerRadius: 5, style: .continuous))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
