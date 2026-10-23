import CleenKit
import SwiftUI

/// The Emoji tab, as in OmniNotch: search on top, a grid of large emoji below. A click
/// pastes the emoji into the app you were in; Return pastes the best match.
struct NotchEmojiTab: View {
    @State private var model = EmojiModel.shared
    @Environment(NotchState.self) private var notch
    @FocusState private var searchFocused: Bool
    @State private var confirmation: Confirmation?

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
                EmojiGrid(model: model, use: use)
            }
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

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.tertiary)
            TextField("Buscar emoji", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFocused)
                .onSubmit { if let first = model.results.first { use(first) } }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.tertiary)
                }
                .buttonStyle(.plain)
                .help("Limpar busca")
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 200, height: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(NotchStyle.primary.opacity(0.18))
        }
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

    private func use(_ item: EmojiItem) {
        notch.isPinned = false
        let pasted = model.use(item)
        let shown = Confirmation(emoji: item.emoji, pasted: pasted, stamp: .now)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { confirmation = shown }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if confirmation == shown { withAnimation(.smooth(duration: 0.2)) { confirmation = nil } }
        }
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
