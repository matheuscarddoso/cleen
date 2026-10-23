import SwiftUI

/// The open panel: header in the notch strip, then either the selected tool with the
/// tab bar, or Ajustes.
struct NotchOpenContent: View {
    let controller: NotchController
    let notchHeight: Double
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            NotchHeader(controller: controller)
                .frame(height: notchHeight)
                .padding(.horizontal, NotchOpenContent.inset - 2)
            if state.showsSettings {
                NotchSettingsView()
                    .padding(.horizontal, NotchOpenContent.inset)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            } else {
                tool
                    .padding(.horizontal, NotchOpenContent.inset)
                    // minHeight 0: a tall tool clips instead of pushing the tab bar down, so the
                    // bar sits at the same height on every tab.
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .padding(.top, 6)
                // The expanded mirror and Início's edit mode take the tab bar's room too.
                if !hidesTabBar {
                    NotchTabBar()
                        .padding(.bottom, 10)
                        .padding(.top, 6)
                        .transition(.opacity)
                }
            }
        }
        .foregroundStyle(NotchStyle.primary)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: hidesTabBar)
    }

    private var hidesTabBar: Bool { state.tab == .home && (state.mirrorExpanded || state.isEditingHome) }

    /// Room between the panel's rounded edge and its content.
    static let inset = 20.0

    @ViewBuilder
    private var tool: some View {
        switch state.tab {
        case .home: NotchHomeTab()
        case .calendar: NotchCalendarTab()
        case .shelf: NotchShelfTab()
        case .clipboard: NotchClipboardTab()
        case .screenshots: NotchScreenshotsTab()
        case .ai: NotchAIUsageTab()
        case .timer: NotchTimerTab()
        case .notes: NotchNotesTab()
        case .reminders: NotchRemindersTab()
        case .converter: NotchConverterTab()
        case .emoji: NotchEmojiTab()
        case .weather: NotchWeatherTab()
        case .shortcuts: NotchShortcutsTab()
        case .agents: NotchAgentsTab()
        case .overview: NotchOverviewTab(controller: controller)
        case .clean: NotchCleanTab()
        case .projects: NotchProjectsTab()
        case .files: NotchFilesTab()
        case .duplicates: NotchDuplicatesTab()
        case .space: NotchSpaceTab()
        case .apps: NotchAppsTab()
        case .leftovers: NotchLeftoversTab()
        case .system: NotchSystemTab()
        case .startup: NotchStartupTab()
        case .maintenance: NotchMaintenanceTab()
        }
    }
}
