import AppKit
import CleenKit
import SwiftUI

/// Mensagens, Droppy's way: the latest conversations (who, the last message, unread,
/// when), and under the picked one a reply bar with quick reactions. Replies go out
/// through Messages itself.
struct NotchMessagesTab: View {
    @Environment(MessagesModel.self) private var messages
    @State private var draft = ""
    @State private var showsReactions = false
    @FocusState private var isTyping: Bool

    static let reactions = ["😂", "❤️", "🥹", "🙏", "😮", "👍"]

    var body: some View {
        Group {
            switch messages.access {
            case .needsFullDiskAccess:
                NotchPrompt(
                    symbol: "message.fill",
                    color: MessageBubbleBadge.blue,
                    title: String(localized: "Permita o Acesso Total ao Disco"),
                    message: String(localized: "O Cleen lê as suas conversas do Mensagens neste Mac para mostrá-las aqui. Nada sai do seu Mac."),
                    buttonTitle: String(localized: "Abrir Ajustes")
                ) { NSWorkspace.shared.open(FullDiskAccess.settingsURL) }
            case .unknown:
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .granted:
                if messages.threads.isEmpty {
                    Text("Nenhuma conversa nas últimas duas semanas")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    conversations
                }
            }
        }
        .onAppear {
            messages.contacts.requestAccess()
            if messages.access == .needsFullDiskAccess { messages.retry() }
        }
    }

    private var conversations: some View {
        VStack(spacing: 8) {
            NotchScroll {
                VStack(spacing: 0) {
                    ForEach(Array(messages.threads.prefix(4).enumerated()), id: \.element.id) { index, thread in
                        if index > 0 { Rectangle().fill(NotchStyle.separator).frame(height: 1).padding(.leading, 52) }
                        MessageThreadRow(thread: thread, isSelected: messages.selectedChat == thread.id) {
                            withAnimation(.smooth(duration: 0.25)) { messages.selectedChat = thread.id }
                            isTyping = true
                        }
                    }
                }
            }
            if showsReactions {
                reactionBar.transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
            } else {
                replyBar.transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
            }
            if let error = messages.sendError {
                Text(error)
                    .font(.system(size: 10.5))
                    .foregroundStyle(NotchStyle.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showsReactions)
    }

    private var selected: ChatThread? {
        messages.threads.first { $0.id == messages.selectedChat } ?? messages.threads.first
    }

    private var replyBar: some View {
        HStack(spacing: 8) {
            TextField(selected?.last.service ?? "iMessage", text: $draft, prompt: Text(verbatim: "\(selected?.last.service ?? "iMessage")…").foregroundStyle(NotchStyle.tertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isTyping)
                .onSubmit { send(draft) }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(NotchStyle.control.opacity(0.7), in: .capsule)
            Button { send(draft) } label: {
                Image(systemName: messages.isSending ? "ellipsis" : "paperplane.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(MessageBubbleBadge.blue.opacity(draft.isEmpty ? 0.4 : 1), in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || messages.isSending)
            .help("Enviar")
            Button { showsReactions = true } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                    .frame(width: 32, height: 32)
                    .background(NotchStyle.control.opacity(0.7), in: .circle)
            }
            .buttonStyle(.plain)
            .help("Reagir")
        }
    }

    private var reactionBar: some View {
        HStack(spacing: 4) {
            ForEach(Self.reactions, id: \.self) { emoji in
                Button {
                    send(emoji)
                    showsReactions = false
                } label: {
                    Text(verbatim: emoji)
                        .font(.system(size: 19))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(MessageReactionStyle())
            }
            Button { showsReactions = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NotchStyle.secondary)
                    .frame(width: 28, height: 28)
                    .background(NotchStyle.control.opacity(0.7), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(height: 38)
        .background(NotchStyle.control.opacity(0.45), in: .capsule)
    }

    private func send(_ text: String) {
        guard let chat = selected?.id else { return }
        let message = text
        Task {
            if await messages.send(message, to: chat), message == draft { draft = "" }
        }
    }
}

private struct MessageReactionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// One conversation: picture or initials with Messages' badge, who and the last
/// message, unread and when.
struct MessageThreadRow: View {
    let thread: ChatThread
    let isSelected: Bool
    let select: () -> Void
    @Environment(MessagesModel.self) private var messages
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 11) {
                MessageAvatar(name: messages.title(of: thread), image: thread.last.isGroup ? nil : messages.contacts.image(for: thread.handle), size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(messages.title(of: thread))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    preview
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(MessageTime.short(thread.last.date))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(NotchStyle.tertiary)
                    if thread.unread > 0 {
                        Text(verbatim: "\(thread.unread)")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 17, minHeight: 17)
                            .background(Color(red: 1, green: 0.27, blue: 0.27), in: .capsule)
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isSelected ? NotchStyle.control.opacity(0.55) : (isHovered ? NotchStyle.control.opacity(0.3) : .clear), in: .rect(cornerRadius: 12, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Abrir no Mensagens") { messages.open(thread) }
        }
        .animation(.smooth(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var preview: some View {
        let last = thread.last
        let text = last.text.isEmpty ? (last.imagePath != nil ? String(localized: "📷 Foto") : String(localized: "Anexo")) : last.text
        if last.isFromMe {
            (Text("Você: ") + Text(text))
                .font(.system(size: 12))
                .foregroundStyle(MessageBubbleBadge.blue)
                .lineLimit(1)
        } else {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(NotchStyle.secondary)
                .lineLimit(1)
        }
    }
}

/// A contact's picture, or their initials on grey, with Messages' blue badge.
struct MessageAvatar: View {
    let name: String
    let image: NSImage?
    let size: Double

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [Color(white: 0.62), Color(white: 0.45)], startPoint: .top, endPoint: .bottom)
                    Text(verbatim: Self.initials(name))
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(alignment: .bottomTrailing) {
            MessageBubbleBadge().frame(width: size * 0.38, height: size * 0.38).offset(x: 2, y: 2)
        }
    }

    static func initials(_ name: String) -> String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        let letters = words.prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "#" : letters.uppercased()
    }
}

/// Messages' little blue bubble.
struct MessageBubbleBadge: View {
    static let blue = Color(red: 0.13, green: 0.55, blue: 1)

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            Circle().fill(Self.blue).padding(1.5)
            Image(systemName: "message.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

/// "agora", "5 min", "14:02", "ontem".
enum MessageTime {
    static func short(_ date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return String(localized: "agora") }
        if seconds < 3600 { return String(localized: "\(Int(seconds / 60)) min") }
        if Calendar.current.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if Calendar.current.isDateInYesterday(date) { return String(localized: "ontem") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// A new message on the closed notch: the notch grows into an island with who sent
/// it and what they said (or the picture).
struct MessageIsland: View {
    let message: ChatMessage
    let sender: String
    let image: NSImage?
    let notchHeight: Double

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                MessageAvatar(name: sender, image: image, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sender)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(NotchStyle.primary)
                        .lineLimit(1)
                    Text(message.text.isEmpty ? (message.imagePath != nil ? String(localized: "📷 Foto") : String(localized: "Anexo")) : message.text)
                        .font(.system(size: 12))
                        .foregroundStyle(NotchStyle.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let path = message.imagePath, let picture = NSImage(contentsOfFile: path) {
                    Image(nsImage: picture)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                } else {
                    Text("agora")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchStyle.tertiary)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}
