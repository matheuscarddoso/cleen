import SwiftUI

/// The notch's front page: a greeting, then the person's widgets (what's playing, the
/// day and the mirror unless they changed it). The mirror grows to fill the panel when
/// tapped; the header's grid button rearranges everything in place.
struct NotchHomeTab: View {
    @Environment(NowPlayingModel.self) private var nowPlaying
    @Environment(AgendaModel.self) private var agenda
    @Environment(NotchState.self) private var state
    @Environment(HomeLayout.self) private var layout
    @Namespace private var mirrorSpace

    var body: some View {
        ZStack(alignment: .top) {
            if state.mirrorExpanded {
                MirrorExpanded(namespace: mirrorSpace)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if state.isEditingHome {
                        HomeEditBar()
                            .transition(.opacity)
                    } else if layout.showsGreeting {
                        NotchGreeting()
                            .transition(.opacity)
                    }
                    if layout.items.isEmpty {
                        emptyState
                    } else {
                        HomeWidgetRow(items: layout.items, available: available, mirrorSpace: mirrorSpace, isEditing: state.isEditingHome)
                            .padding(.top, state.isEditingHome ? 6 : 0)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: state.mirrorExpanded)
        .animation(.smooth(duration: 0.3), value: state.isEditingHome)
        .task { await nowPlaying.watch() }
        .task { await agenda.watch() }
    }

    /// The panel's width minus its rounded edge and content inset on both sides.
    private var available: Double {
        let panel = state.geometry?.openSize.width ?? NotchGeometry.openPanelSize.width
        return panel - 2 * (NotchStyle.openTopRadius + NotchOpenContent.inset)
    }

    private var emptyState: some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) { state.isEditingHome = true }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16))
                    .foregroundStyle(NotchStyle.tertiary)
                Text(state.isEditingHome ? String(localized: "Toque num widget acima para adicionar") : String(localized: "Início vazio · toque para escolher widgets"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(state.isEditingHome)
    }
}
