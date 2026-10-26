import AppKit
import CleenKit
import CoreServices
import Observation

/// Files and folders by name, from the Spotlight index (no folder walking): the newest
/// used first, nothing from Library or hidden folders.
///
/// Asks Spotlight through MDQuery, synchronously, on a background queue. NSMetadataQuery
/// isn't used: it raised Objective-C exceptions from inside Swift code (building its
/// predicate), which took the app down a moment later.
@Observable
final class FileSearch {
    struct Result: Identifiable, Equatable, Sendable {
        let url: URL
        let name: String
        let lastUsed: Date?
        var id: String { url.path(percentEncoded: false) }
    }

    private(set) var results: [Result] = []
    private(set) var isSearching = false
    /// Called once results come in, to rebuild the list around them.
    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var limit = 8
    @ObservationIgnored private(set) var text = ""

    /// Searches after a short pause in typing; a new call replaces the one in flight.
    func search(_ text: String, limit: Int) {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard text != self.text || limit != self.limit else { return }
        self.text = text
        self.limit = limit
        pending?.cancel()
        guard text.count >= 2 else {
            isSearching = false
            if !results.isEmpty { results = []; onChange() }
            return
        }
        isSearching = true
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            let found = await offMain { Self.find(text, limit: limit) }
            guard !Task.isCancelled, let self, self.text == text else { return }
            self.isSearching = false
            guard found != self.results else { return }
            self.results = found
            self.onChange()
        }
    }

    func cancel() {
        pending?.cancel()
        text = ""
        results = []
        isSearching = false
    }

    /// Blocking: runs the Spotlight query to the end. Every typed word must be somewhere
    /// in the name ("nota fiscal" finds "Nota Fiscal - março.pdf").
    nonisolated static func find(_ text: String, limit: Int) -> [Result] {
        let words = text.split(whereSeparator: \.isWhitespace).map { word in
            // Spotlight's query language: quotes, backslashes and wildcards are escaped.
            let escaped = word.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "?", with: "\\?")
            return "kMDItemFSName == \"*\(escaped)*\"cd"
        }
        guard !words.isEmpty,
              let query = MDQueryCreate(kCFAllocatorDefault, words.joined(separator: " && ") as CFString, [kMDItemPath, kMDItemDisplayName, kMDItemLastUsedDate] as CFArray, nil)
        else { return [] }
        var home = URL.homeDirectory.path(percentEncoded: false)
        if home.hasSuffix("/") { home.removeLast() }
        MDQuerySetSearchScope(query, [home, "/Applications"] as CFArray, 0)
        // Enough to sort by use and still have `limit` left after the filtering below.
        MDQuerySetMaxCount(query, 400)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return [] }
        defer { MDQueryStop(query) }

        var found: [Result] = []
        for index in 0..<MDQueryGetResultCount(query) {
            guard let raw = MDQueryGetResultAtIndex(query, index) else { continue }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String else { continue }
            // Caches, app support and dotfolders are noise in a launcher.
            let relative = path.hasPrefix(home) ? String(path.dropFirst(home.count)) : path
            if relative.hasPrefix("/Library/") || relative.contains("/.") || path.hasSuffix(".app") || relative.contains(".app/") { continue }
            if relative.split(separator: "/").contains(where: { toolFolders.contains(String($0)) }) { continue }
            found.append(Result(
                url: URL(filePath: path),
                name: (MDItemCopyAttribute(item, kMDItemDisplayName) as? String) ?? URL(filePath: path).lastPathComponent,
                lastUsed: MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
            ))
        }
        return Array(found.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }.prefix(limit))
    }

    /// Folders full of files nobody opens by hand: package managers, SDKs, build output.
    /// (Apps are left out too: they already lead the search as apps.)
    nonisolated private static let toolFolders: Set<String> = [
        "node_modules", "fvm", "Pods", "DerivedData", "venv", "site-packages", "__pycache__", "vendor", "bower_components", "Carthage",
    ]
}
