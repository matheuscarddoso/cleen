import SwiftUI

struct TabSettingRow: View {
    @Environment(TabPreferences.self) private var tabs
    let tab: NotchTab
    @State private var isOn: Bool

    init(tab: NotchTab) {
        self.tab = tab
        _isOn = State(initialValue: true)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchStyle.tertiary)
            Image(systemName: tab.symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 18)
            Text(tab.settingsTitle)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            NotchSwitch(label: tab.settingsTitle, isOn: $isOn)
                .disabled(isOn && tabs.visible.count == 1)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .onAppear { isOn = tabs.isVisible(tab) }
        .onChange(of: isOn) { _, visible in
            tabs.setVisible(visible, for: tab)
            isOn = tabs.isVisible(tab)
        }
    }
}
