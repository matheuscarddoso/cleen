import CleenKit
import SwiftUI

/// The Atalhos tab: run the person's macOS Shortcuts. Search and folders on top, the
/// shortcuts as a grid of tiles below, pinned first. Return runs the top result.
struct NotchShortcutsTab: View {
    @Environment(ShortcutsModel.self) private var model
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            switch model.phase {
            case .idle, .loading:
                loading
            case .failed(let message):
                NotchPrompt(
                    symbol: "exclamationmark.triangle.fill",
                    color: ToolPalette.orange,
                    title: "Não deu para ler seus atalhos",
                    message: message,
                    buttonTitle: "Tentar de novo",
                    action: model.refresh
                )
            case .loaded where model.library.shortcuts.isEmpty:
                NotchPrompt(
                    symbol: "square.2.layers.3d",
                    color: ToolPalette.indigo,
                    title: "Nenhum atalho ainda",
                    message: "Crie um atalho no app Atalhos e rode daqui com um clique.",
                    buttonTitle: "Abrir Atalhos",
                    action: model.openShortcutsApp
                )
                .overlay(alignment: .topTrailing) { refreshButton }
            case .loaded:
                VStack(alignment: .leading, spacing: 10) {
                    toolbar
                    grid
                }
                // Focus once the tab has settled, as Clipboard does: making the field first
                // responder on the switch's frame stalled it.
                .task {
                    try? await Task.sleep(for: .milliseconds(350))
                    searchFocused = true
                }
            }
        }
        .onAppear(perform: model.loadIfNeeded)
    }

    private var loading: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(.white)
            Text("Lendo seus atalhos")
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.tertiary)
                TextField("Buscar", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                    .onSubmit(runTopResult)
                if !model.query.isEmpty {
                    Button { model.query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchStyle.tertiary)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .help("Limpar busca")
                    .accessibilityLabel("Limpar busca")
                }
            }
            .padding(.horizontal, 9)
            .frame(width: 180, height: 26)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(NotchStyle.primary.opacity(0.18))
            }
            if !model.library.folders.isEmpty {
                folderPills
            }
            Spacer(minLength: 0)
            if let failure = model.lastFailure {
                Text("\(failure.name): \(failure.message)")
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.critical)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 220, alignment: .trailing)
                    .layoutPriority(1)
                    .help(failure.message)
                    .transition(.opacity)
            }
            refreshButton
            NotchIconButton(symbol: "arrow.up.forward.app", help: "Abrir o app Atalhos", action: model.openShortcutsApp)
        }
        .frame(height: 26)
        .animation(.smooth(duration: 0.2), value: model.lastFailure)
    }

    /// "Todos" plus one pill per Shortcuts folder; scrolls sideways when there are many.
    private var folderPills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ClipboardKindPill(title: "Todos", isSelected: model.folderID == nil) { model.folderID = nil }
                ForEach(model.library.folders) { folder in
                    ClipboardKindPill(title: folder.name, isSelected: model.folderID == folder.id) { model.folderID = folder.id }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeFade(.horizontal, length: 18)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var refreshButton: some View {
        if model.isRefreshing {
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
                .frame(width: 26, height: 24)
                .accessibilityLabel("Atualizando")
        } else {
            NotchIconButton(symbol: "arrow.clockwise", help: "Atualizar lista", action: model.refresh)
        }
    }

    // MARK: Grid

    @ViewBuilder
    private var grid: some View {
        let shortcuts = model.visible
        if shortcuts.isEmpty {
            VStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(NotchStyle.tertiary)
                Text("Nada encontrado")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let suggested = model.query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : shortcuts.first?.id
            NotchScroll {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 104), spacing: 6)], spacing: 6) {
                    ForEach(shortcuts) { entry in
                        ShortcutTile(entry: entry, isSuggested: entry.id == suggested)
                    }
                }
                .padding(.bottom, 4)
            }
            .animation(.smooth(duration: 0.2), value: shortcuts.map(\.id))
        }
    }

    private func runTopResult() {
        guard !model.query.trimmingCharacters(in: .whitespaces).isEmpty, let first = model.visible.first else { return }
        model.run(first)
    }
}
