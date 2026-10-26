import AppKit
import ApplicationServices
import os

/// A call ringing on the Mac (the iPhone's, through Continuity, or FaceTime): macOS
/// shows it in a banner of its own, and Cleen reads that banner through Accessibility
/// (already granted for the volume keys): who's calling, and its Accept and Decline
/// buttons, which the notch can then press.
@Observable
final class IncomingCallWatcher {
    struct Ringing: Equatable {
        let caller: String
        /// "From Your iPhone", "FaceTime Audio"…
        let detail: String
        fileprivate let accept: AXElementBox?
        fileprivate let decline: AXElementBox?

        static func == (a: Ringing, b: Ringing) -> Bool { a.caller == b.caller && a.detail == b.detail }
    }

    private(set) var ringing: Ringing?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var loggedWindows: Set<CGWindowID> = []
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "calls")

    /// The processes that draw call banners.
    private static let owners: Set<String> = ["Notification Center", "NotificationCenter", "FaceTime", "InCallService", "CallServicesUI", "TelephonyUtilities"]

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.check()
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    func accept() {
        ringing?.accept?.press()
        ringing = nil
    }

    func decline() {
        ringing?.decline?.press()
        ringing = nil
    }

    private func check() {
        guard AXIsProcessTrusted() else {
            if ringing != nil { ringing = nil }
            return
        }
        let banners = Self.bannerWindows()
        guard !banners.isEmpty else {
            if ringing != nil { ringing = nil }
            return
        }
        var found: Ringing?
        for banner in banners {
            let app = AXUIElementCreateApplication(banner.pid)
            let content = Self.read(app)
            if !loggedWindows.contains(banner.id) {
                loggedWindows.insert(banner.id)
                // What a banner holds, to tell a call from any other notification.
                Self.log.notice("banner from \(banner.owner, privacy: .public): texts \(content.texts, privacy: .private) buttons \(content.buttons.map(\.label), privacy: .public)")
            }
            if let call = Self.call(in: content) {
                found = call
                break
            }
        }
        if found != ringing { ringing = found }
    }

    // MARK: Reading the banner

    private struct Banner {
        let id: CGWindowID
        let pid: pid_t
        let owner: String
    }

    private static func bannerWindows() -> [Banner] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let owner = info[kCGWindowOwnerName as String] as? String, owners.contains(owner),
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) > 150, (bounds["Height"] ?? 0) > 40
            else { return nil }
            return Banner(id: id, pid: pid, owner: owner)
        }
    }

    private struct Content {
        var texts: [String] = []
        var buttons: [(label: String, element: AXUIElement)] = []
    }

    private static func read(_ app: AXUIElement) -> Content {
        var content = Content()
        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        for window in (windows as? [AXUIElement]) ?? [] {
            walk(window, depth: 0, into: &content)
        }
        return content
    }

    private static func walk(_ element: AXUIElement, depth: Int, into content: inout Content) {
        guard depth < 14, content.texts.count < 40 else { return }
        let role = string(element, kAXRoleAttribute)
        if role == kAXStaticTextRole as String, let value = string(element, kAXValueAttribute), !value.isEmpty {
            content.texts.append(value)
        }
        if role == kAXButtonRole as String {
            let label = string(element, kAXDescriptionAttribute) ?? string(element, kAXTitleAttribute) ?? string(element, kAXIdentifierAttribute) ?? ""
            content.buttons.append((label, element))
        }
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        for child in (children as? [AXUIElement]) ?? [] {
            walk(child, depth: depth + 1, into: &content)
        }
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static let acceptWords = ["accept", "aceitar", "atender", "answer"]
    private static let declineWords = ["decline", "recusar", "rejeitar", "end", "encerrar"]
    private static let callWords = ["iphone", "facetime", "call", "chamada", "ligação", "ligando", "calling"]

    /// A call banner: something saying it's a call, and an accept button.
    private static func call(in content: Content) -> Ringing? {
        let lower = content.texts.map { $0.lowercased() }
        let accept = content.buttons.first { button in acceptWords.contains { button.label.lowercased().contains($0) } }
        let decline = content.buttons.first { button in declineWords.contains { button.label.lowercased().contains($0) } }
        let saysCall = lower.contains { text in callWords.contains { text.contains($0) } }
        guard accept != nil, saysCall || decline != nil else { return nil }
        let caller = content.texts.first ?? String(localized: "Ligação")
        let detail = content.texts.dropFirst().first ?? String(localized: "Ligação")
        return Ringing(caller: caller, detail: detail, accept: accept.map { AXElementBox($0.element) }, decline: decline.map { AXElementBox($0.element) })
    }
}

/// A banner's button, held to press it later.
fileprivate final class AXElementBox {
    let element: AXUIElement
    init(_ element: AXUIElement) { self.element = element }
    func press() { AXUIElementPerformAction(element, kAXPressAction as CFString) }
}
