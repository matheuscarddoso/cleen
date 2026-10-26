import AppKit
import CleenKit
import SwiftUI

/// Clipboard history as in OmniNotch: search and type pills on top, the copies as a
/// row of cards. Click a card to paste it; ← → move, Return pastes, ⌘1–⌘9 paste the
/// first nine straight away (holding ⌘ shows their numbers).
struct NotchClipboardTab: View {
    @Environment(ClipboardModel.self) private var model
    @Environment(NotchState.self) private var notch
    @Environment(AppModel.self) private var app
    @FocusState private var searchFocused: Bool
    @State private var commandHeld = false
    @State private var flagsMonitor: Any?

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.tertiary)
                    TextField("Buscar", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($searchFocused)
                        .onSubmit(pasteSelected)
                }
                .padding(.horizontal, 9)
                .frame(width: 200, height: 26)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(NotchStyle.primary.opacity(0.18))
                }
                ClipboardKindPill(title: String(localized: "Tudo"), isSelected: model.kind == nil) { model.kind = nil }
                ForEach(ClipboardEntry.Kind.allCases, id: \.self) { kind in
                    ClipboardKindPill(title: kind.title, isSelected: model.kind == kind) { model.kind = kind }
                }
                Spacer()
                ClipboardMoreMenu()
            }
            ClipboardCards(showsNumbers: commandHeld, paste: paste)
        }
        .onKeyPress(.leftArrow) { model.moveSelection(by: -1); return .handled }
        .onKeyPress(.rightArrow) { model.moveSelection(by: 1); return .handled }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard press.modifiers.contains(.command), let number = Int(press.characters), (1...9).contains(number) else { return .ignored }
            let entries = model.visible
            guard entries.indices.contains(number - 1) else { return .handled }
            paste(entries[number - 1])
            return .handled
        }
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                commandHeld = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
                return event
            }
        }
        .onDisappear {
            if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
            flagsMonitor = nil
            commandHeld = false
        }
        // Focus once the tab has settled: making the field first responder sets up the
        // text system and input method, which stalled the switch when done on its frame.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            searchFocused = true
        }
    }

    private func pasteSelected() {
        if let entry = model.selected { paste(entry) }
    }

    /// Back on the clipboard, then pasted where you were typing, with the notch closed.
    private func paste(_ entry: ClipboardEntry) {
        notch.isPinned = false
        model.copy(entry)
        app.notch.closeAndPaste()
    }
}
