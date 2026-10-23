import AppKit
import CleenKit
import SwiftUI

/// The Conversor tab, as in OmniNotch: categories on top, then the value you type and
/// its conversion side by side with a swap between them. Return pastes the result.
struct NotchConverterTab: View {
    @State private var model = ConverterModel.shared
    @FocusState private var inputFocused: Bool
    @State private var copiedAt: Date?
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ConverterCategoryBar(selection: $model.category)
            if model.category == .currency, model.rates == nil {
                ConverterRatesUnavailable(isLoading: model.ratesState == .loading, retry: model.refreshRatesIfNeeded)
            } else {
                boxes
                ConverterFootnote(model: model)
            }
        }
        .task {
            if model.category == .currency { model.refreshRatesIfNeeded() }
            // Focus once the tab has settled, like the clipboard's search: making the
            // field first responder on the switch's frame stalled it.
            try? await Task.sleep(for: .milliseconds(350))
            inputFocused = true
        }
    }

    private var boxes: some View {
        HStack(spacing: 8) {
            ConverterBox(units: model.units, selected: model.from, select: model.setFrom) {
                TextField("0", text: $model.input)
                    .textFieldStyle(.plain)
                    .font(.converterValue)
                    .foregroundStyle(model.value == nil && !model.input.isEmpty ? NotchStyle.critical : NotchStyle.primary)
                    .focused($inputFocused)
                    .onSubmit(pasteResult)
                    .accessibilityLabel("Valor em \(model.from.name)")
            }
            ConverterSwapButton(action: swap)
            ConverterBox(units: model.units, selected: model.to, select: model.setTo, copied: copiedAt != nil, copy: copyAction) {
                Text(model.resultText)
                    .font(.converterValue)
                    .foregroundStyle(model.result == nil ? NotchStyle.tertiary : NotchStyle.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .textSelection(.enabled)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.18), value: model.resultText)
                    .accessibilityLabel("\(model.resultText) \(model.to.name)")
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var copyAction: (() -> Void)? {
        guard model.result != nil else { return nil }
        return copyResult
    }

    private func swap() {
        withAnimation(.smooth(duration: 0.22)) { model.swap() }
    }

    /// Return: the result pasted where you were typing, the notch closed.
    private func pasteResult() {
        guard model.result != nil else { return }
        copyResult()
        app.notch.closeAndPaste()
    }

    /// Copies the converted number as shown, without the unit, ready to paste.
    private func copyResult() {
        guard model.result != nil else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(model.resultText, forType: .string)
        let stamp = Date.now
        withAnimation(.smooth(duration: 0.15)) { copiedAt = stamp }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if copiedAt == stamp { withAnimation(.smooth(duration: 0.2)) { copiedAt = nil } }
        }
    }
}
