import SwiftUI

/// The open panel: header in the notch strip, then either the selected tool with the
/// tab bar, or Ajustes.
struct NotchOpenContent: View {
    let controller: NotchController
    let notchHeight: Double
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            // Reading, the teleprompter has the whole panel, the camera's strip included.
            if !isPrompting {
                NotchHeader(controller: controller)
                    .frame(height: notchHeight)
                    .padding(.horizontal, NotchOpenContent.inset - 2)
                    .transition(.opacity)
            }
            if state.showsSearch {
                NotchSearchView(controller: controller)
                    .padding(.top, 2)
                    .transition(.opacity)
            } else if state.showsSettings {
                NotchSettingsView()
                    .padding(.horizontal, NotchOpenContent.inset)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            } else {
                tool
                    .padding(.horizontal, isPrompting ? 0 : NotchOpenContent.inset)
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .padding(.top, isPrompting ? 0 : 6)
                    // The tabs float in their dock below; the tool keeps an inset above the edge.
                    .padding(.bottom, state.showsTabDock ? 14 : 0)
            }
        }
        .foregroundStyle(NotchStyle.primary)
        // The review covers the tool (and Ajustes), which stay as they were underneath.
        .overlay(alignment: .top) {
            if let review = state.deletionReview {
                DeletionReviewView(review: review)
                    .padding(.horizontal, NotchOpenContent.inset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(NotchStyle.background)
                    .padding(.top, notchHeight)
                    .transition(.opacity)
                    .id(review.id)
            }
        }
        .overlay(alignment: .bottom) {
            if state.pasteNeedsPermission {
                PastePermissionBanner()
                    .padding(.horizontal, NotchOpenContent.inset)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: state.pasteNeedsPermission)
    }

    private var isPrompting: Bool { state.isPrompting && state.tab == .teleprompter }

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
        case .icons: NotchIconsTab()
        case .stocks: NotchStocksTab()
        case .teleprompter: NotchTeleprompterTab()
        case .recorder: NotchRecorderTab()
        case .assistant: NotchAssistantTab()
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
