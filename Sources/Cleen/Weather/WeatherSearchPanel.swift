import AppKit
import CleenKit
import SwiftUI

/// Picking the place: a city search over Open-Meteo's geocoder, or the Mac's location.
/// ↑ ↓ move through the results, Return picks, Esc closes (when there's a place to go
/// back to).
struct WeatherSearchPanel: View {
    /// Closes the search; `nil` when there's nothing behind it (no place yet).
    var close: (() -> Void)?
    @Environment(WeatherModel.self) private var model
    @State private var query = ""
    @State private var results: [WeatherPlace] = []
    @State private var status = Status.idle
    @State private var selection = 0
    @FocusState private var fieldFocused: Bool

    private enum Status: Equatable {
        case idle
        case searching
        case done
        case failed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                field
                locationButton
                Spacer(minLength: 0)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onKeyPress(.upArrow) { move(by: -1) }
        .onKeyPress(.downArrow) { move(by: 1) }
        .onKeyPress(.escape) {
            guard let close else { return .ignored }
            close()
            return .handled
        }
        .task(id: query) { await search() }
        // Focus once the tab has settled, as the clipboard search does: becoming first
        // responder on the tab's first frame stalled the switch.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            fieldFocused = true
        }
    }

    // MARK: Controls

    private var field: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.tertiary)
            TextField("Buscar cidade", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($fieldFocused)
                .onSubmit(pickSelected)
            if status == .searching {
                ProgressView().controlSize(.mini).tint(.white)
            } else if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.tertiary)
                }
                .buttonStyle(.plain)
                .help("Limpar")
                .accessibilityLabel("Limpar a busca")
            }
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: 240)
        .frame(height: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(NotchStyle.primary.opacity(fieldFocused ? 0.28 : 0.18))
        }
        .animation(.smooth(duration: 0.15), value: fieldFocused)
    }

    private var locationButton: some View {
        Button(action: model.useCurrentLocation) {
            HStack(spacing: 6) {
                if model.isLocating {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: "location.fill").font(.system(size: 10, weight: .medium))
                }
                Text(model.isLocating ? String(localized: "Localizando…") : String(localized: "Usar minha localização"))
            }
        }
        .buttonStyle(.notchSecondary)
        .disabled(model.isLocating)
        .fixedSize()
    }

    // MARK: Results

    @ViewBuilder
    private var content: some View {
        if let problem = model.locationProblem {
            HStack(spacing: 8) {
                Image(systemName: "location.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchStyle.warning)
                Text(problem.message)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
                if problem == .denied {
                    Button("Abrir Ajustes", action: Self.openLocationSettings)
                        .buttonStyle(.plain)
                        .font(NotchStyle.captionMedium)
                        .foregroundStyle(NotchStyle.primary)
                }
            }
            .lineLimit(1)
            .transition(.opacity)
        }
        if !results.isEmpty {
            resultGrid
        } else {
            Text(hint)
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.tertiary)
                .padding(.leading, 2)
                .contentTransition(.opacity)
        }
    }

    private var hint: String {
        switch status {
        case .idle: String(localized: "Digite o nome de uma cidade.")
        case .searching: String(localized: "Buscando…")
        case .done: String(localized: "Nenhuma cidade com esse nome.")
        case .failed: String(localized: "Sem conexão para buscar agora.")
        }
    }

    /// Two columns: six results fit in three rows, no scrolling at the default panel size.
    private var resultGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
            ForEach(Array(results.enumerated()), id: \.offset) { index, place in
                WeatherPlaceRow(place: place, isSelected: index == selection) { model.choose(place) }
            }
        }
    }

    // MARK: Behavior

    /// Waits for a pause in typing, so a city name is one request rather than one per
    /// letter; a newer query cancels this one.
    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            results = []
            status = .idle
            return
        }
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }
        status = .searching
        let result = await OpenMeteo.search(text)
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let places):
            withAnimation(.smooth(duration: 0.2)) { results = places }
            selection = 0
            status = .done
        case .failure:
            status = .failed
        }
    }

    private func move(by step: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        selection = min(max(selection + step, 0), results.count - 1)
        return .handled
    }

    private func pickSelected() {
        guard results.indices.contains(selection) else { return }
        model.choose(results[selection])
    }

    private static func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// One geocoding result: the city, and the state and country that tell it apart.
private struct WeatherPlaceRow: View {
    let place: WeatherPlace
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? NotchStyle.primary : NotchStyle.tertiary)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(place.name)
                        .font(NotchStyle.bodyMedium)
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle)
                            .font(NotchStyle.caption)
                            .foregroundStyle(NotchStyle.tertiary)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: .rect(cornerRadius: 9, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.12), value: isHovered)
        .accessibilityLabel([place.name, place.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    private var background: Color {
        if isSelected { return NotchStyle.selection }
        return isHovered ? NotchStyle.control.opacity(0.6) : .clear
    }
}
