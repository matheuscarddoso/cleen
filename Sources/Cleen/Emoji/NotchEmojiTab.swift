import CleenKit
import SwiftUI

/// The Emoji tab, as in OmniNotch: search on top, a grid of large emoji below. A click
/// pastes the emoji into the app you were in; Return pastes the best match.
struct NotchEmojiTab: View {
    @State private var model = EmojiModel.shared
    @Environment(NotchState.self) private var notch
    @Environment(AppModel.self) private var app
    @FocusState private var searchFocused: Bool
    @State private var confirmation: Confirmation?
    @State private var selection = 0
    @State private var columns = 16
    /// The column ↑ and ↓ aim for, kept across shorter rows like a text cursor's.
    @State private var goalColumn = 0

    struct Confirmation: Equatable {
        let emoji: String
        let pasted: Bool
        let stamp: Date
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    searchField
                    Spacer(minLength: 8)
                    EmojiCategoryJumps(
                        categories: jumpTargets,
                        jump: { target in jump(to: target, proxy: proxy) }
                    )
                }
                EmojiGrid(model: model, selection: selection, columns: $columns, select: point, use: use)
            }
            .onChange(of: selection) { _, position in
                proxy.scrollTo(EmojiCellID(position: position))
            }
        }
        // A new search starts on its best match.
        .onChange(of: model.query) {
            selection = 0
            goalColumn = 0
        }
        .overlay(alignment: .bottom) {
            if let confirmation {
                EmojiConfirmation(emoji: confirmation.emoji, pasted: confirmation.pasted)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)).combined(with: .offset(y: 4)))
                    .id(confirmation.stamp)
            }
        }
        .task {
            model.updateRecents()
            await model.load()
        }
        // Focus once the tab has settled, like the clipboard's search.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            searchFocused = true
        }
    }

    /// The field, in the notch's one surface (the card) like the launcher's: the arrows
    /// walk the grid from here, Return pastes the selected emoji, Esc clears.
    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
            TextField("Buscar emoji", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit(useSelected)
                .onKeyPress(.leftArrow) { move(-1) }
                .onKeyPress(.rightArrow) { move(1) }
                .onKeyPress(.upArrow) { moveRow(-1) }
                .onKeyPress(.downArrow) { moveRow(1) }
                .onKeyPress(.tab) { move(1) }
                .onKeyPress(.escape) {
                    guard !model.query.isEmpty else { return .ignored }
                    model.query = ""
                    return .handled
                }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(NotchStyle.tertiary)
                }
                .buttonStyle(.plain)
                .help("Limpar busca")
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: 280)
        .frame(height: 30)
        .background(NotchStyle.card, in: .rect(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(searchFocused ? NotchStyle.primary.opacity(0.16) : NotchStyle.cardStroke)
        }
        .animation(.smooth(duration: 0.15), value: searchFocused)
    }

    /// Moves the selection by `step` cells, holding at either end. With words typed and
    /// nothing found, ← and → move the text cursor instead.
    private func move(_ step: Int) -> KeyPress.Result {
        if abs(step) == 1, !model.query.isEmpty, !model.isSearching || model.results.isEmpty { return .ignored }
        let count = EmojiGrid.order(of: model).count
        guard count > 0 else { return .ignored }
        selection = min(max(selection + step, 0), count - 1)
        let rows = EmojiGrid.rows(of: model, columns: columns)
        if let row = rows.first(where: { $0.contains(selection) }), let column = row.firstIndex(of: selection) { goalColumn = column }
        return .handled
    }

    /// The pointer picks a cell: it becomes the selection, and its column the goal.
    private func point(at position: Int) {
        selection = position
        let rows = EmojiGrid.rows(of: model, columns: columns)
        if let row = rows.first(where: { $0.contains(position) }), let column = row.firstIndex(of: position) { goalColumn = column }
    }

    /// ↑ and ↓: the row above or below, in the goal column (or the row's last cell when
    /// it's shorter), across section boundaries.
    private func moveRow(_ step: Int) -> KeyPress.Result {
        let rows = EmojiGrid.rows(of: model, columns: columns)
        guard let current = rows.firstIndex(where: { $0.contains(selection) }) else { return .ignored }
        let target = current + step
        guard rows.indices.contains(target) else { return .handled }
        let row = rows[target]
        selection = row[min(goalColumn, row.count - 1)]
        return .handled
    }

    private func useSelected() {
        let order = EmojiGrid.order(of: model)
        guard !order.isEmpty else { return }
        use(order[min(selection, order.count - 1)])
    }

    private var jumpTargets: [EmojiJumpTarget] {
        let categories = model.sections.map { EmojiJumpTarget.category($0.category) }
        return model.recents.isEmpty ? categories : [.recents] + categories
    }

    private func jump(to target: EmojiJumpTarget, proxy: ScrollViewProxy) {
        let wasSearching = model.isSearching
        model.query = ""
        Task {
            // Leaving a search swaps the results for the full grid; scroll once it's there.
            if wasSearching { await Task.yield() }
            withAnimation(.smooth(duration: 0.3)) { proxy.scrollTo(target, anchor: .top) }
        }
    }

    /// Pastes the emoji where you were typing and gets out of the way.
    private func use(_ item: EmojiItem) {
        notch.isPinned = false
        model.copy(item)
        app.notch.closeAndPaste()
    }
}

/// The small pill that confirms a pick.
private struct EmojiConfirmation: View {
    let emoji: String
    let pasted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 14))
            // Without Accessibility it couldn't paste: say how to finish the job.
            Text(pasted ? String(localized: "Copiado") : String(localized: "Copiado, cole com ⌘V"))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(NotchStyle.primary)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        // Opaque under the lift, so the grid doesn't show through.
        .background {
            Capsule().fill(NotchStyle.background)
            Capsule().fill(NotchStyle.selection)
        }
        .overlay { Capsule().strokeBorder(NotchStyle.cardStroke) }
        .accessibilityElement(children: .combine)
    }
}
