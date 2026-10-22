import Foundation

/// A launchd job: something macOS starts on its own, at login or at boot.
public struct LaunchItem: Sendable, Identifiable, Hashable {
    public enum Scope: String, Sendable, CaseIterable {
        /// `~/Library/LaunchAgents`: runs as you, removable without a password.
        case user = "Seu usuário"
        /// `/Library/LaunchAgents`: runs as every user who logs in.
        case allUsers = "Todos os usuários"
        /// `/Library/LaunchDaemons`: runs as root, before anyone logs in.
        case system = "Sistema"

        public var needsAdministrator: Bool { self != .user }
    }

    public var id: URL { plist }
    public let plist: URL
    public let label: String
    public let program: URL?
    public let arguments: [String]
    public let scope: Scope
    public let runsAtLoad: Bool
    public let keepsAlive: Bool
    /// Turned off, either in its plist or by a launchd override (what "Desativar" does).
    public let isDisabled: Bool
    public let isLoaded: Bool
    public let signature: SignatureStatus

    /// Human name: the program's file name, falling back to the label.
    public var displayName: String {
        if let program, signature != .script {
            let bundle = program.pathComponents.first { $0.hasSuffix(".app") }
            return bundle.map { String($0.dropLast(4)) } ?? program.lastPathComponent
        }
        return label
    }
}
