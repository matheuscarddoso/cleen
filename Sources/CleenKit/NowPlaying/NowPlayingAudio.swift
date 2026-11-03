import Foundation

/// A process Core Audio knows as a client, and whether it's sending sound out right now.
public struct AudioProcess: Sendable, Equatable {
    public let pid: Int32
    /// The process that started it (0 when unknown): a browser's helpers are its children.
    public let parentPID: Int32
    /// Empty when Core Audio has none (a command-line tool).
    public let bundleID: String
    public let isRunningOutput: Bool

    public init(pid: Int32, parentPID: Int32 = 0, bundleID: String, isRunningOutput: Bool) {
        self.pid = pid
        self.parentPID = parentPID
        self.bundleID = bundleID
        self.isRunningOutput = isRunningOutput
    }
}

/// Ties the Now Playing app to the processes that actually play its sound.
///
/// Most apps play from their own process. Browsers don't: Chromium browsers (Chrome,
/// Arc, Dia, Brave, Edge, Vivaldi, Opera) and Electron apps play from a helper they
/// start themselves, so it's their child, usually with a bundle ID that extends theirs
/// (`com.google.Chrome.helper`; Dia's is `company.thebrowser.browser.helper`, which is
/// why the parent counts). Safari plays from WebKit's GPU process, an XPC service with
/// no tie to Safari but its bundle ID. The "responsible process" that would tie any
/// helper to its app is private API and was left out on purpose.
public enum NowPlayingAudio {
    /// Helpers whose bundle ID doesn't start with the app's own.
    static let helpers: [String: [String]] = [
        "com.apple.Safari": ["com.apple.WebKit.GPU", "com.apple.WebKit.WebContent"],
        "com.apple.SafariTechnologyPreview": ["com.apple.WebKit.GPU", "com.apple.WebKit.WebContent"],
        "org.mozilla.firefox": ["org.mozilla.plugincontainer"],
        "org.mozilla.firefoxdeveloperedition": ["org.mozilla.plugincontainer"],
        "org.mozilla.nightly": ["org.mozilla.plugincontainer"],
    ]

    /// Browsers known to play only from helpers: with no helper listed in Core Audio,
    /// they're making no sound at all.
    static let helperOnly = Set([
        "com.google.Chrome", "company.thebrowser.Browser", "company.thebrowser.dia", "com.brave.Browser",
        "com.microsoft.edgemac", "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    ]).union(helpers.keys)

    /// Whether `process` plays sound for the app with this pid and bundle ID.
    ///
    /// A known parent decides on its own: bundle IDs are shared (Arc's and Dia's helpers
    /// are both `company.thebrowser.browser.helper`), so another app's child never counts
    /// however its bundle ID reads. The bundle ID only ties helpers with no parent but
    /// launchd, like WebKit's XPC services, or whose parent Cleen couldn't read.
    public static func matches(_ process: AudioProcess, pid: Int32, bundleID: String?) -> Bool {
        if pid > 0, process.pid == pid || process.parentPID == pid { return true }
        guard process.parentPID <= 1 else { return false }
        guard let bundleID, !bundleID.isEmpty, !process.bundleID.isEmpty else { return false }
        if process.bundleID.lowercased().hasPrefix(bundleID.lowercased() + ".") { return true }
        return helpers[bundleID]?.contains(process.bundleID) ?? false
    }

    /// Whether the app is making sound right now, or nil when Core Audio can't say: the
    /// app has no audio client of its own to watch (it may play through a daemon).
    public static func isAudible(pid: Int32, bundleID: String?, in processes: [AudioProcess]) -> Bool? {
        let own = processes.filter { matches($0, pid: pid, bundleID: bundleID) }
        if own.contains(where: \.isRunningOutput) { return true }
        if !own.isEmpty { return false }
        return bundleID.map(helperOnly.contains) == true ? false : nil
    }

    /// Whether this app is a browser that plays from helpers only.
    public static func playsThroughHelpers(_ bundleID: String?) -> Bool {
        bundleID.map(helperOnly.contains) ?? false
    }
}
