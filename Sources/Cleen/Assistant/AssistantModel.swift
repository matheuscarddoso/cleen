import AppKit
import FoundationModels
import Observation

/// One turn of the conversation on screen.
struct AssistantMessage: Identifiable, Equatable {
    enum Role {
        case question
        case answer
    }

    let id = UUID()
    let role: Role
    var text: String
    var isStreaming = false
    /// Why the answer stopped short, in the person's words.
    var failure: String?
}

/// Questions answered by Apple Intelligence's on-device model: nothing leaves the Mac.
/// The conversation lives here, not in the tab, so it survives the notch folding up
/// while an answer is still coming in.
@Observable
final class AssistantModel {
    enum Availability: Equatable {
        case available
        case deviceNotEligible
        case turnedOff
        case notReady
        case unavailable
    }

    private(set) var messages: [AssistantMessage] = []
    private(set) var isResponding = false
    /// What's typed in the field, kept across tab switches.
    var draft = ""

    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var responseTask: Task<Void, Never>?

    /// Read on every render: the system model is Observable, so this follows Apple
    /// Intelligence being turned on or finishing its download.
    var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): .turnedOff
        case .unavailable(.modelNotReady): .notReady
        case .unavailable: .unavailable
        }
    }

    var canSend: Bool {
        !isResponding && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Loads the model ahead of the first question, so the answer starts sooner.
    func prepare() {
        guard availability == .available else { return }
        currentSession().prewarm()
    }

    func send() {
        guard canSend else { return }
        let question = draft
        draft = ""
        ask(question)
    }

    /// Asks in the open conversation. Also the way in from elsewhere in Cleen (a "?"
    /// query in the search): an answer still coming in is stopped first.
    func ask(_ question: String) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, availability == .available else { return }
        if isResponding { stop() }
        messages.append(AssistantMessage(role: .question, text: question))
        let answer = AssistantMessage(role: .answer, text: "", isStreaming: true)
        messages.append(answer)
        isResponding = true
        let session = currentSession()
        responseTask = Task { [weak self] in
            do {
                for try await snapshot in session.streamResponse(to: question) {
                    guard !Task.isCancelled else { break }
                    self?.update(answer.id) { $0.text = snapshot.content }
                }
                self?.finish(answer.id, failure: nil)
            } catch is CancellationError {
                self?.finish(answer.id, failure: nil)
            } catch {
                self?.finish(answer.id, failure: Self.describe(error))
            }
        }
    }

    /// Stops the answer where it is. The session is rebuilt from what was said so far,
    /// so the next question keeps the context without racing the cancelled one.
    func stop() {
        guard isResponding else { return }
        responseTask?.cancel()
        responseTask = nil
        if let session {
            self.session = LanguageModelSession(transcript: session.transcript)
        }
        if let id = messages.last(where: { $0.isStreaming })?.id {
            finish(id, failure: nil)
        }
    }

    func newConversation() {
        responseTask?.cancel()
        responseTask = nil
        isResponding = false
        messages = []
        session = nil
        prepare()
    }

    func copy(_ message: AssistantMessage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.text, forType: .string)
    }

    func openSettings() {
        // Apple Intelligence e Siri, in System Settings.
        if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Private

    private func currentSession() -> LanguageModelSession {
        if let session { return session }
        let session = LanguageModelSession(instructions: Self.instructions)
        self.session = session
        return session
    }

    private func update(_ id: UUID, _ change: (inout AssistantMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }

    private func finish(_ id: UUID, failure: String?) {
        update(id) {
            $0.isStreaming = false
            $0.failure = failure
        }
        // A newer question may already be running; only the last answer owns the flag.
        if messages.last?.id == id || messages.last(where: { $0.isStreaming }) == nil {
            isResponding = false
        }
    }

    private static let instructions = """
        You answer questions from the person using this Mac, inside a small panel under \
        the notch. Always reply in the same language the person writes in. Be concise: \
        lead with the answer, then at most a few short sentences or a short list. Use \
        Markdown only for bold, lists and inline code. If you don't know, say so plainly.
        """

    private static func describe(_ error: any Error) -> String {
        guard let error = error as? LanguageModelSession.GenerationError else {
            return String(localized: "Não deu para responder. Tente de novo.")
        }
        switch error {
        case .exceededContextWindowSize:
            return String(localized: "A conversa ficou longa demais. Comece uma nova.")
        case .guardrailViolation, .refusal:
            return String(localized: "Não posso responder a isso.")
        case .unsupportedLanguageOrLocale:
            return String(localized: "Esse idioma ainda não é compatível.")
        case .rateLimited, .concurrentRequests:
            return String(localized: "Muitos pedidos seguidos. Tente de novo em instantes.")
        case .assetsUnavailable:
            return String(localized: "O modelo não está disponível agora.")
        default:
            return String(localized: "Não deu para responder. Tente de novo.")
        }
    }
}
