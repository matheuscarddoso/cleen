import SwiftUI

/// The frame every AI usage card shares: an icon, a name, an optional plan badge.
struct AIUsageCard<Content: View>: View {
    let title: String
    let symbol: String
    var badge: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                if let badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(NotchStyle.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(NotchStyle.control, in: .rect(cornerRadius: 4))
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .notchCard(padding: 10)
    }
}
