import Foundation
import Security

public enum CodeSignature {
    static let interpreters: Set<String> = [
        "sh", "bash", "zsh", "dash", "fish", "python", "python3", "perl", "ruby", "node", "osascript", "env",
    ]

    /// Judges the program a launch item runs.
    public static func status(of program: URL) -> SignatureStatus {
        let path = program.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else { return .missing }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(program as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode
        else { return .unsigned }

        let validity = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil)
        if validity == errSecCSUnsigned { return .unsigned }
        guard validity == errSecSuccess else { return .broken }

        if interpreters.contains(program.lastPathComponent) { return .script }

        var requirement: SecRequirement?
        if SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement) == errSecSuccess,
           let requirement, SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess {
            return .apple
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any]
        else { return .unsigned }

        // Ad-hoc signatures (no certificate) vouch for nothing.
        guard let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first
        else { return .unsigned }

        let summary = SecCertificateCopySubjectSummary(leaf) as String? ?? ""
        return .developer(team: cleanSigner(summary, team: info[kSecCodeInfoTeamIdentifier as String] as? String))
    }

    /// `Developer ID Application: Docker Inc (9BNSXJN65R)` → `Docker Inc`.
    static func cleanSigner(_ summary: String, team: String?) -> String {
        var name = summary
        for prefix in ["Developer ID Application: ", "Apple Development: ", "Apple Distribution: ", "3rd Party Mac Developer Application: "]
        where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
        }
        if let open = name.lastIndex(of: "("), name.hasSuffix(")") {
            name = name[..<open].trimmingCharacters(in: .whitespaces)
        }
        return name.isEmpty ? (team ?? "Desenvolvedor identificado") : name
    }
}
