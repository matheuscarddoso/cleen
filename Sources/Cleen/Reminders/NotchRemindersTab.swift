import SwiftUI

/// The Lembretes tab, as OmniNotch's To-Dos: a field on top that adds to Reminders on
/// Return, then the open reminders, starred first.
struct NotchRemindersTab: View {
    @Environment(AgendaModel.self) private var agenda
    @Environment(NotchState.self) private var notch
    @State private var draft = ""
    @State private var failed = false
    @State private var failureReset: Task<Void, Never>?
    /// The panel is kept open because something is being typed.
    @State private var holdsForTyping = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if agenda.remindersAccess == .denied {
                NotchPrompt(
                    symbol: "checklist",
                    color: ToolPalette.orange,
                    title: "Sem acesso aos Lembretes",
                    message: "Permita em Ajustes do Sistema › Privacidade e Segurança › Lembretes para ver e criar lembretes aqui.",
                    buttonTitle: "Abrir Ajustes do Sistema",
                    action: AgendaModel.openRemindersPrivacySettings
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        field
                        NotchIconButton(symbol: "arrow.up.forward.app", help: "Abrir o app Lembretes", action: AgendaModel.openReminders)
                    }
                    list
                }
                .padding(.bottom, 2)
                // Focus once the tab has settled, as the clipboard's search does.
                .task {
                    try? await Task.sleep(for: .milliseconds(350))
                    fieldFocused = true
                }
            }
        }
        .task { await agenda.watch() }
        .onChange(of: draft) { _, text in
            if text.isEmpty { releaseHold() } else { holdWhileTyping() }
        }
        .onChange(of: fieldFocused) { _, focused in
            if !focused { releaseHold() }
        }
        .onDisappear {
            failureReset?.cancel()
            releaseHold()
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(draft.isEmpty ? NotchStyle.tertiary : NotchStyle.primary)
            TextField("Novo lembrete", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($fieldFocused)
                .onSubmit(add)
                .disabled(agenda.remindersAccess != .granted)
            if failed {
                Text("Não deu para criar")
                    .font(NotchStyle.captionMedium)
                    .foregroundStyle(NotchStyle.critical)
                    .transition(.opacity)
            } else if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                Image(systemName: "return")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchStyle.tertiary)
                    .help("Return adiciona")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            // A click on the field's margin still lands in it.
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(NotchStyle.card)
                .onTapGesture { fieldFocused = true }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(fieldFocused ? NotchStyle.primary.opacity(0.18) : NotchStyle.cardStroke)
                .allowsHitTesting(false)
        }
        .animation(.smooth(duration: 0.15), value: draft.isEmpty)
        .animation(.smooth(duration: 0.15), value: failed)
        .animation(.smooth(duration: 0.18), value: fieldFocused)
    }

    @ViewBuilder
    private var list: some View {
        if agenda.reminders.isEmpty {
            if agenda.remindersAccess == .granted {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(NotchStyle.tertiary)
                    Text("Nenhum lembrete em aberto")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                // Still asking for access: nothing to say yet.
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            NotchScroll {
                LazyVStack(spacing: 1) {
                    ForEach(agenda.reminders) { reminder in
                        ReminderListRow(reminder: reminder)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
                    }
                }
            }
        }
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let created = withAnimation(.smooth(duration: 0.25)) { agenda.createReminder(title: title) }
        if created {
            draft = ""
        } else {
            failed = true
            failureReset?.cancel()
            failureReset = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                failed = false
            }
        }
        // Return leaves the field ready for the next one.
        fieldFocused = true
    }

    /// Typing keeps the panel open even if the pointer drifts off it; a click elsewhere
    /// or Esc still closes it.
    private func holdWhileTyping() {
        guard fieldFocused, !holdsForTyping else { return }
        holdsForTyping = true
        notch.holdsOpen = true
    }

    private func releaseHold() {
        guard holdsForTyping else { return }
        holdsForTyping = false
        notch.holdsOpen = false
    }
}
