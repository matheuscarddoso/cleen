import AppKit
import CleenKit
import SwiftUI

/// The Ícones tab: search Lucide's icons (lucide.dev) and copy one as SVG, name, JSX or
/// a Blade/HTML tag. Search on top, a grid of icons below; a click copies the SVG and
/// Return copies the top match's.
struct NotchIconsTab: View {
    @Environment(LucideModel.self) private var model
    @Environment(AppModel.self) private var app
    @FocusState private var searchFocused: Bool
    @State private var confirmation: Confirmation?

    struct Confirmation: Equatable {
        let icon: LucideIcon
        let message: String
        let failed: Bool
        let stamp: Date
    }

    var body: some View {
        // One container for every phase, so the load below runs once per visit and not
        // again each time the phase swaps the content.
        ZStack {
            switch model.phase {
            case .idle, .reading:
                Color.clear
            case .downloading(let fraction):
                IconsDownloading(fraction: fraction)
            case .failed:
                NotchPrompt(
                    symbol: "wifi.exclamationmark",
                    color: ToolPalette.orange,
                    title: String(localized: "Não deu para baixar os ícones"),
                    message: String(localized: "Confira a conexão. Os ícones do Lucide são baixados uma vez só e depois ficam no Mac."),
                    buttonTitle: String(localized: "Tentar de novo"),
                    action: model.retry
                )
            case .ready:
                VStack(alignment: .leading, spacing: 8) {
                    toolbar
                    IconsGrid(model: model, copy: copy)
                }
                // Focus once the tab has settled, like the clipboard's search.
                .task {
                    try? await Task.sleep(for: .milliseconds(350))
                    searchFocused = true
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let confirmation {
                IconsConfirmation(confirmation: confirmation)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)).combined(with: .offset(y: 4)))
                    .id(confirmation.stamp)
            }
        }
        .task {
            model.updateRecents()
            await model.load()
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.tertiary)
                TextField("Buscar ícone", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                    .onSubmit(copyTopResult)
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
            .frame(width: 200, height: 26)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(NotchStyle.primary.opacity(0.18))
            }
            Spacer(minLength: 8)
            Text(countLabel)
                .font(NotchStyle.caption)
                .monospacedDigit()
                .foregroundStyle(NotchStyle.tertiary)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.2), value: countLabel)
            NotchIconButton(symbol: "arrow.up.forward.app", help: String(localized: "Abrir lucide.dev")) {
                NSWorkspace.shared.open(URL(string: "https://lucide.dev/icons/")!)
            }
        }
        .frame(height: 26)
    }

    /// "1.903 ícones" while browsing, "12 resultados" while searching.
    private var countLabel: String {
        let count = model.isSearching ? model.results.count : model.icons.count
        let number = count.formatted(.number.locale(.cleen))
        if model.isSearching {
            return count == 1 ? String(localized: "1 resultado") : String(localized: "\(number) resultados")
        }
        return count == 1 ? String(localized: "1 ícone") : String(localized: "\(number) ícones")
    }

    // MARK: Copying

    /// Return: the top result's SVG, pasted where you were typing.
    private func copyTopResult() {
        guard model.isSearching, let first = model.results.first else { return }
        Task {
            if await model.copySVG(first) {
                app.notch.closeAndPaste()
            } else {
                confirm(Confirmation(icon: first, message: String(localized: "Sem conexão para baixar o SVG"), failed: true, stamp: .now))
            }
        }
    }

    private func copy(_ icon: LucideIcon, _ kind: LucideCopyKind) {
        Task {
            let copied: Bool
            switch kind {
            case .svg: copied = await model.copySVG(icon)
            case .name: model.copyName(icon); copied = true
            case .jsx: model.copyJSX(icon); copied = true
            case .html: model.copyHTML(icon); copied = true
            }
            confirm(Confirmation(
                icon: icon,
                message: copied ? kind.done : String(localized: "Sem conexão para baixar o SVG"),
                failed: !copied,
                stamp: .now
            ))
        }
    }

    private func confirm(_ shown: Confirmation) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { confirmation = shown }
        Task {
            try? await Task.sleep(for: .seconds(shown.failed ? 2.2 : 1.2))
            if confirmation == shown { withAnimation(.smooth(duration: 0.2)) { confirmation = nil } }
        }
    }
}

/// The first download: what's happening and how far along.
private struct IconsDownloading: View {
    let fraction: Double

    var body: some View {
        VStack(spacing: 9) {
            Text("Baixando os ícones do Lucide")
                .font(NotchStyle.bodyMedium)
            UsageBar(fraction: fraction, tint: NotchStyle.barFill)
                .frame(width: 180)
            Text(fraction.formatted(.percent.precision(.fractionLength(0)).locale(.cleen)))
                .font(NotchStyle.caption)
                .monospacedDigit()
                .foregroundStyle(NotchStyle.tertiary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The small pill that confirms a copy, with the icon itself.
private struct IconsConfirmation: View {
    let confirmation: NotchIconsTab.Confirmation

    var body: some View {
        HStack(spacing: 6) {
            if confirmation.failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.warning)
            } else {
                LucideGlyph(icon: confirmation.icon, size: 15)
                    .foregroundStyle(NotchStyle.primary)
            }
            Text(confirmation.message)
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
