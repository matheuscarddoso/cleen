import CleenKit
import SwiftUI

/// The Perguntar tab: Apple Intelligence, on this Mac. The conversation above, the
/// field at the bottom; answers stream in as they're written.
struct NotchAssistantTab: View {
    @Environment(AssistantModel.self) private var model
    @Environment(NotchState.self) private var notch

    var body: some View {
        Group {
            switch model.availability {
            case .available:
                AssistantChat()
            case .deviceNotEligible:
                AssistantNotice(
                    symbol: "desktopcomputer",
                    title: String(localized: "Este Mac não tem Apple Intelligence"),
                    message: String(localized: "Ela precisa de um Mac com chip Apple, do M1 em diante.")
                )
            case .turnedOff:
                AssistantNotice(
                    symbol: "apple.intelligence",
                    title: String(localized: "A Apple Intelligence está desligada"),
                    message: String(localized: "Ligue em Ajustes do Sistema › Apple Intelligence e Siri para perguntar aqui."),
                    button: (String(localized: "Abrir Ajustes"), model.openSettings)
                )
            case .notReady:
                AssistantNotice(
                    symbol: "arrow.down.circle",
                    title: String(localized: "O modelo está sendo baixado"),
                    message: String(localized: "A Apple Intelligence ainda está se preparando neste Mac. Isso leva alguns minutos."),
                    isWorking: true
                )
            case .unavailable:
                AssistantNotice(
                    symbol: "exclamationmark.triangle",
                    title: String(localized: "A Apple Intelligence não está pronta"),
                    message: String(localized: "Tente de novo daqui a pouco.")
                )
            }
        }
        .animation(.smooth(duration: 0.2), value: model.availability)
        .onAppear {
            // Esc stops an answer first; the next one closes the notch.
            notch.escapeHandler = { [model] in
                guard model.isResponding else { return false }
                model.stop()
                return true
            }
        }
        .onDisappear { notch.escapeHandler = nil }
    }
}

/// Why there's nothing to ask yet, and the one thing to do about it.
private struct AssistantNotice: View {
    let symbol: String
    let title: String
    let message: String
    var button: (title: String, action: () -> Void)?
    var isWorking = false

    var body: some View {
        VStack(spacing: 10) {
            ToolIcon(symbol: symbol, color: Color(white: 0.22), size: 32)
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    if isWorking {
                        ProgressView().controlSize(.mini)
                    }
                    Text(title)
                        .font(NotchStyle.headline)
                }
                Text(message)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            if let button {
                Button(button.title, action: button.action)
                    .buttonStyle(.notchPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chat

private struct AssistantChat: View {
    @Environment(AssistantModel.self) private var model
    @Environment(NotchState.self) private var notch
    @FocusState private var fieldFocused: Bool
    @State private var holdsForTyping = false

    var body: some View {
        VStack(spacing: 8) {
            if model.messages.isEmpty {
                emptyState
                    .transition(.opacity)
            } else {
                AssistantTranscript()
                    .transition(.opacity)
            }
            promptBar
        }
        .padding(.bottom, 2)
        .animation(.smooth(duration: 0.2), value: model.messages.isEmpty)
        // Focus once the tab has settled: making the field first responder sets up the
        // text system and input method, which stalled the switch when done on its frame.
        .task {
            model.prepare()
            try? await Task.sleep(for: .milliseconds(350))
            fieldFocused = true
        }
        .onChange(of: fieldFocused) { _, focused in
            if !focused { releaseHold() }
        }
        .onDisappear(perform: releaseHold)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .accessibilityHidden(true)
            Text("Pergunte qualquer coisa")
                .font(NotchStyle.headline)
            Text("A Apple Intelligence responde aqui mesmo. Nada sai do Mac.")
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var promptBar: some View {
        @Bindable var model = model
        return HStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("Pergunte algo…", text: $model.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($fieldFocused)
                    .onSubmit(model.send)
                    .onChange(of: model.draft) { holdWhileTyping() }
                    .accessibilityLabel("Pergunta")
                sendButton
            }
            .padding(.leading, 11)
            .padding(.trailing, 3)
            .frame(height: 30)
            .background(NotchStyle.card, in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(fieldFocused ? NotchStyle.primary.opacity(0.18) : NotchStyle.cardStroke)
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: fieldFocused)
            NotchIconButton(symbol: "square.and.pencil", help: String(localized: "Nova conversa")) {
                withAnimation(.smooth(duration: 0.22)) { model.newConversation() }
                fieldFocused = true
            }
            .disabled(model.messages.isEmpty)
            .opacity(model.messages.isEmpty ? 0.4 : 1)
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    /// Send while there's a question; stop while an answer is coming in.
    private var sendButton: some View {
        let responding = model.isResponding
        let enabled = responding || model.canSend
        return Button {
            if responding { model.stop() } else { model.send() }
        } label: {
            Image(systemName: responding ? "stop.fill" : "arrow.up")
                .font(.system(size: responding ? 9 : 11, weight: .semibold))
                .foregroundStyle(enabled ? Color.black : NotchStyle.tertiary)
                .frame(width: 24, height: 24)
                .background(enabled ? Color.white : NotchStyle.control, in: .circle)
                .contentTransition(.symbolEffect(.replace))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.smooth(duration: 0.15), value: enabled)
        .help(responding ? String(localized: "Parar (Esc)") : String(localized: "Perguntar (↩)"))
        .accessibilityLabel(responding ? String(localized: "Parar") : String(localized: "Perguntar"))
    }

    /// Typing keeps the panel open even if the pointer drifts off it.
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

/// The conversation, pinned to its newest line while an answer streams in.
private struct AssistantTranscript: View {
    @Environment(AssistantModel.self) private var model

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(model.messages) { message in
                        switch message.role {
                        case .question: QuestionBubble(text: message.text)
                        case .answer: AnswerView(message: message)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollEdgeFade()
            .onChange(of: model.messages.count) {
                guard let last = model.messages.last else { return }
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// The person's question, as a grey bubble on the right.
private struct QuestionBubble: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 12.5))
            .foregroundStyle(NotchStyle.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(NotchStyle.selection, in: .rect(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 420, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// An answer as plain text on the panel, Markdown rendered, with copy on hover.
private struct AnswerView: View {
    @Environment(AssistantModel.self) private var model
    let message: AssistantMessage
    @State private var isHovered = false
    @State private var copied = false
    @State private var copyReset: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                if message.text.isEmpty, message.isStreaming {
                    ThinkingDots()
                } else if !message.text.isEmpty {
                    Text(Self.rendered(message.text))
                        .font(.system(size: 12.5))
                        .lineSpacing(2)
                        .foregroundStyle(NotchStyle.primary)
                        .tint(NotchStyle.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let failure = message.failure {
                    Label(failure, systemImage: "exclamationmark.circle")
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !message.isStreaming, !message.text.isEmpty {
                NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: copied ? String(localized: "Copiada") : String(localized: "Copiar resposta"), isActive: copied, action: copy)
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(isHovered || copied ? 1 : 0)
                    .animation(.smooth(duration: 0.15), value: isHovered)
            }
        }
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .onDisappear { copyReset?.cancel() }
    }

    private func copy() {
        model.copy(message)
        copied = true
        copyReset?.cancel()
        copyReset = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    /// Inline Markdown on top of plain-text blocks; if it doesn't parse (half a link
    /// mid-stream), the raw text shows instead of nothing.
    private static func rendered(_ markdown: String) -> AttributedString {
        let prepared = ChatMarkdown.prepare(markdown)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        return (try? AttributedString(markdown: prepared, options: options)) ?? AttributedString(prepared)
    }
}

/// Three dots breathing in turn while the first words are on their way.
private struct ThinkingDots: View {
    var body: some View {
        PhaseAnimator([0, 1, 2]) { phase in
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(NotchStyle.secondary)
                        .frame(width: 5, height: 5)
                        .opacity(index == phase ? 1 : 0.35)
                }
            }
        } animation: { _ in .easeInOut(duration: 0.35) }
        .frame(height: 18)
        .accessibilityLabel("Pensando")
    }
}
