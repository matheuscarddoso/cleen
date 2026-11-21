import Foundation

/// Takes out of a report's text what points to its owner: the home folder in every path,
/// the account's and the Mac's names, e-mail addresses. Applied to everything a report
/// carries before it's queued, whatever produced it.
public struct PersonalDataScrubber: Sendable {
    private let home: String
    /// Names to take out wherever they appear, longest first so a full name goes before
    /// the first name inside it.
    private let names: [String]

    /// `names`: the account's short and full names, the Mac's name. Anything under three
    /// letters is left alone: taking "Al" out would mangle symbols and paths.
    public init(home: String, names: [String]) {
        self.home = home.hasSuffix("/") ? String(home.dropLast()) : home
        self.names = Set(names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 3 })
            .sorted { $0.count > $1.count }
    }

    /// This Mac's account and name.
    public static var current: PersonalDataScrubber {
        PersonalDataScrubber(
            home: NSHomeDirectory(),
            names: [NSUserName(), NSFullUserName(), Host.current().localizedName ?? ""]
        )
    }

    public func scrub(_ text: String) -> String {
        var out = text
        if !home.isEmpty { out = out.replacingOccurrences(of: home, with: "~") }
        // Any other account's folder that turns up (a shared Mac, a mounted disk).
        out = out.replacing(/\/Users\/(?!Shared\/)[^\/"\s]+/, with: "/Users/<user>")
        out = out.replacing(/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/, with: "<email>")
        for name in names {
            out = out.replacingOccurrences(of: name, with: "<redacted>", options: [.caseInsensitive])
        }
        return out
    }
}
