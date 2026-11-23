import Foundation

/// Which Apple team may sign the build that replaces the copy running.
///
/// The updater only swaps in a build signed by the team that signed the running copy,
/// so a tampered feed or download can't hand over someone else's app. A team that
/// passes distribution on to another is listed in `successors`: builds signed by the
/// old team accept the new one, and from then on the new team's builds accept only
/// their own.
public enum UpdateSigner {
    /// The development team that signed up to 1.3.1 hands over to the Developer ID team
    /// that signs and notarizes every release after it.
    static let successors = ["9QGGX38JS2": "AS86DUYNV9"]

    /// Whether a build signed by `incoming` may replace one signed by `running`. Unsigned
    /// (nil) on either side never passes.
    public static func accepts(_ incoming: String?, replacing running: String?) -> Bool {
        guard let incoming, let running, !incoming.isEmpty else { return false }
        return incoming == running || successors[running] == incoming
    }
}
