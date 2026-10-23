import SwiftUI

struct SettingsSidebar: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(SettingsSection.groups.indices, id: \.self) { index in
                    let group = SettingsSection.groups[index]
                    if let title = group.title {
                        Text(title.uppercased())
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(NotchStyle.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                    }
                    ForEach(group.sections) { section in
                        SettingsSidebarRow(section: section, isSelected: state.settingsSection == section) {
                            state.settingsSection = section
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollEdgeFade()
        .scrollBounceBehavior(.basedOnSize)
    }
}
