import SwiftUI

/// Every tool with a switch and a drag handle, as in OmniNotch's Tabs page.
struct TabSettings: View {
    @Environment(TabPreferences.self) private var tabs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach(tabs.order) { tab in
                    TabSettingRow(tab: tab)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onMove(perform: tabs.move)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: Double(tabs.order.count) * 32)
            .background(NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke)
            }
            HStack {
                Text("Arraste para mudar a ordem.")
                    .font(.system(size: 10))
                    .foregroundStyle(NotchStyle.tertiary)
                Spacer()
                Button("Restaurar padrão", action: tabs.reset)
                    .buttonStyle(.notchSecondary)
            }
        }
    }
}
