import Foundation

public enum SignatureStatus: Sendable, Hashable {
    case apple
    /// Signed with a Developer ID or App Store certificate. `team` is the signer's name.
    case developer(team: String)
    case unsigned
    /// Signed on a Mac without a certificate (local builds, Homebrew bottles). Says the
    /// file wasn't altered since, not who made it.
    case adHoc
    /// Installed by a package manager the person ran themselves (Homebrew, pnpm…).
    case packageManager(name: String)
    /// Signed, but the signature no longer matches the file: it was modified afterwards.
    case broken
    /// The program the item launches doesn't exist anymore.
    case missing
    /// Launches an interpreter (`sh`, `python`…) whose script can't be judged by signature.
    case script

    /// Worth a person's attention: persistence that nobody vouches for.
    public var isSuspicious: Bool {
        switch self {
        case .unsigned, .broken, .script, .adHoc: true
        case .apple, .developer, .missing, .packageManager: false
        }
    }

    public var title: String {
        switch self {
        case .apple: "Apple"
        case .developer(let team): team
        case .unsigned: String(localized: "Sem assinatura")
        case .adHoc: String(localized: "Assinatura local")
        case .packageManager(let name): name
        case .broken: String(localized: "Assinatura inválida")
        case .missing: String(localized: "Programa não existe mais")
        case .script: String(localized: "Script")
        }
    }
}
