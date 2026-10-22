import Foundation
import Security

public enum CodeSignature {
    static let interpreters: Set<String> = [
        "sh", "bash", "zsh", "dash", "fish", "python", "python3", "perl", "ruby", "node", "osascript", "env",
    ]

    /// Where package managers install things. A service started from here was set up
    /// by the person (`brew services start postgresql`), whatever its signature says.
    static func packageManager(for path: String, home: String = Paths.home.path(percentEncoded: false)) -> String? {
        let home = home.trimmingSuffix("/")
        let roots: [(String, String)] = [
            ("/opt/homebrew/", "Homebrew"), ("/usr/local/Cellar/", "Homebrew"), ("/usr/local/opt/", "Homebrew"),
            ("/opt/local/", "MacPorts"), ("/nix/", "Nix"),
            (home + "/Library/pnpm/", "pnpm"), (home + "/.bun/", "Bun"), (home + "/.nvm/", "nvm"),
            (home + "/.volta/", "Volta"), (home + "/.cargo/bin/", "Cargo"), (home + "/.local/share/mise/", "mise"),
            (home + "/.asdf/", "asdf"),
        ]
        return roots.first { path.hasPrefix($0.0) }?.1
    }

    /// Judges the program a launch item runs.
    public static func status(of program: URL) -> SignatureStatus {
        let path = program.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else { return .missing }
        let resolved = program.resolvingSymlinksInPath().path(percentEncoded: false)
        if let manager = packageManager(for: path) ?? packageManager(for: resolved) {
            return .packageManager(name: manager)
        }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(program as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode
        else { return .unsigned }

        // Checks the executable's own signature without hashing every resource in its
        // bundle: that's what matters for "who made this", and it's ~100× faster on big apps.
        let validity = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources), nil)
        if validity == errSecCSUnsigned { return .unsigned }
        guard validity == errSecSuccess else { return .broken }

        if interpreters.contains(program.lastPathComponent) { return .script }

        var requirement: SecRequirement?
        if SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement) == errSecSuccess,
           let requirement,
           SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources), requirement) == errSecSuccess {
            return .apple
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any]
        else { return .unsigned }

        // Ad-hoc signatures carry no certificate: intact, but nobody vouches for them.
        guard let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first
        else { return .adHoc }

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
