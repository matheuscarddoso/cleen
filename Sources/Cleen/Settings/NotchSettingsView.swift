import SwiftUI

/// Ajustes inside the notch: sections on the left, the chosen page on the right.
struct NotchSettingsView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SettingsSidebar()
                .frame(width: 150)
            Rectangle()
                .fill(NotchStyle.separator)
                .frame(width: 1)
                .padding(.horizontal, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.settingsSection.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(state.settingsSection.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    page
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeFade()
            .scrollBounceBehavior(.basedOnSize)
            .id(state.settingsSection)
        }
    }

    @ViewBuilder
    private var page: some View {
        switch state.settingsSection {
        case .general:
            GeneralSettings()
            ClipboardSettings()
            AlertSettings()
        case .notch: NotchAppearanceSettings()
        case .tabs: TabSettings()
        case .cleaning: CleaningSettings()
        case .about:
            PermissionSettings()
            AboutSettings()
        }
    }
}
