import Foundation

public enum SignatureStatus: Sendable, Hashable {
    case apple
    /// Signed with a Developer ID or App Store certificate. `team` is the signer's name.
    case developer(team: String)
    case unsigned
    /// Signed, but the signature no longer matches the file: it was modified afterwards.
    case broken
    /// The program the item launches doesn't exist anymore.
    case missing
    /// Launches an interpreter (`sh`, `python`…) whose script can't be judged by signature.
    case script

    /// Worth a person's attention: persistence that nobody vouches for.
    public var isSuspicious: Bool {
        switch self {
        case .unsigned, .broken, .script: true
        case .apple, .developer, .missing: false
        }
    }

    public var title: String {
        switch self {
        case .apple: "Apple"
        case .developer(let team): team
        case .unsigned: "Sem assinatura"
        case .broken: "Assinatura inválida"
        case .missing: "Programa não existe mais"
        case .script: "Script"
        }
    }
}
