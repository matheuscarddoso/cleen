import CleenKit
import SwiftUI

struct ClipboardKindPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isSelected ? NotchStyle.primary : NotchStyle.secondary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(isSelected ? NotchStyle.selection : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension ClipboardEntry.Kind {
    var title: String {
        switch self {
        case .text: String(localized: "Texto")
        case .link: String(localized: "Links")
        case .image: String(localized: "Imagens")
        case .files: String(localized: "Arquivos")
        }
    }

    var symbol: String {
        switch self {
        case .text: "doc.text"
        case .link: "link"
        case .image: "photo"
        case .files: "doc"
        }
    }
}
