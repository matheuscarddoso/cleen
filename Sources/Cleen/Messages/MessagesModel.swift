import AppKit
import CleenKit
import Contacts
import Observation
import os

/// iMessage in the notch, Droppy's way: the latest conversations with their unread
/// counts, a reply typed right there (sent through Messages itself), and a new message
/// shown on the closed notch as it arrives. Everything is read from Messages' own
/// database on this Mac, which needs Full Disk Access; nothing leaves the Mac.
@Observable
final class MessagesModel {
    enum Access: Equatable {
        case unknown
        case granted
        /// Messages' database can't be read without Full Disk Access.
        case needsFullDiskAccess
    }

    private(set) var access = Access.unknown
    private(set) var threads: [ChatThread] = []
    /// The conversation the reply goes to.
    var selectedChat: String?
    private(set) var isSending = false
    private(set) var sendError: String?
    /// Told about each message that arrives from someone else.
    @ObservationIgnored var onIncoming: (ChatMessage) -> Void = { _ in }

    @ObservationIgnored private var database: MessagesDatabase?
    @ObservationIgnored private var lastID: Int64 = 0
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored let contacts = ContactsResolver()
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "messages")

    static let pollInterval = Duration.seconds(2)

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.check()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    /// Tries again (after the person granted Full Disk Access).
    func retry() {
        database = nil
        check()
    }

    private func check() {
        if database == nil {
            guard let opened = MessagesDatabase() else {
                if access != .needsFullDiskAccess { access = .needsFullDiskAccess }
                return
            }
            database = opened
            lastID = (try? opened.latestID()) ?? 0
            access = .granted
            refreshThreads()
            return
        }
        guard let database, let latest = try? database.latestID() else { return }
        guard latest > lastID else { return }
        let fresh = (try? database.messages(after: lastID)) ?? []
        lastID = latest
        refreshThreads()
        for message in fresh where !message.isFromMe {
            onIncoming(message)
        }
    }

    func refreshThreads() {
        guard let database else { return }
        let found = (try? database.threads(limit: 6)) ?? []
        if found != threads { threads = found }
        if selectedChat == nil || !found.contains(where: { $0.id == selectedChat }) { selectedChat = found.first?.id }
    }

    // MARK: Names

    /// A group's name, else the contact's, else the number or address.
    func title(of thread: ChatThread) -> String {
        if let name = thread.last.chatName { return name }
        return contacts.name(for: thread.handle) ?? thread.handle ?? String(localized: "Mensagem")
    }

    func sender(of message: ChatMessage) -> String {
        if message.isGroup, let name = message.chatName {
            return "\(name) · \(contacts.name(for: message.handle) ?? message.handle ?? "")"
        }
        return contacts.name(for: message.handle) ?? message.handle ?? String(localized: "Mensagem")
    }

    // MARK: Replying

    /// Sends `text` into the conversation through Messages (it asks once to let Cleen
    /// control it).
    func send(_ text: String, to chat: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return false }
        isSending = true
        sendError = nil
        defer { isSending = false }
        let script = """
        tell application "Messages"
            send "\(Self.escaped(trimmed))" to chat id "\(Self.escaped(chat))"
        end tell
        """
        let failure: String? = await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            return error?[NSAppleScript.errorMessage] as? String
        }.value
        if let failure {
            Self.log.error("send failed: \(failure, privacy: .public)")
            sendError = String(localized: "Não deu para enviar. Permita o Cleen controlar o Mensagens em Ajustes do Sistema › Privacidade › Automação.")
            return false
        }
        // The sent message shows once Messages has written it.
        try? await Task.sleep(for: .milliseconds(600))
        check()
        return true
    }

    /// Opens the conversation in Messages.
    func open(_ thread: ChatThread) {
        let target = thread.handle.flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) }
        if let target, let url = URL(string: "imessage://\(target)") {
            NSWorkspace.shared.open(url)
        } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// AppleScript string: backslashes and quotes escaped.
    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Names and pictures for phone numbers and addresses, from Contacts (asked for once,
/// when Mensagens first shows). Without access, the number itself is the name.
@Observable
final class ContactsResolver {
    struct Contact {
        let name: String
        let image: NSImage?
    }

    @ObservationIgnored private var cache: [String: Contact?] = [:]
    private(set) var revision = 0
    @ObservationIgnored private let store = CNContactStore()

    var isAuthorized: Bool { CNContactStore.authorizationStatus(for: .contacts) == .authorized }

    func requestAccess() {
        guard CNContactStore.authorizationStatus(for: .contacts) == .notDetermined else { return }
        Task {
            let granted = (try? await store.requestAccess(for: .contacts)) ?? false
            if granted {
                cache.removeAll()
                revision += 1
            }
        }
    }

    func name(for handle: String?) -> String? { contact(for: handle)?.name }

    func image(for handle: String?) -> NSImage? { contact(for: handle)?.image }

    private func contact(for handle: String?) -> Contact? {
        _ = revision
        guard let handle, isAuthorized else { return nil }
        if let cached = cache[handle] { return cached }
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey, CNContactOrganizationNameKey, CNContactThumbnailImageDataKey] as [CNKeyDescriptor]
        let predicate = handle.contains("@")
            ? CNContact.predicateForContacts(matchingEmailAddress: handle)
            : CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: handle))
        let found = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys))?.first
        let contact = found.map { person -> Contact in
            let full = [person.givenName, person.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let name = !person.nickname.isEmpty ? person.nickname : (!full.isEmpty ? full : person.organizationName)
            return Contact(name: name.isEmpty ? handle : name, image: person.thumbnailImageData.flatMap(NSImage.init(data:)))
        }
        cache[handle] = contact
        return contact
    }
}
