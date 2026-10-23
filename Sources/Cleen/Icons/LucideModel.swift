import AppKit
import CleenKit
import Observation

/// Lucide's icons (lucide.dev): the catalog and its font, the search, the copies.
///
/// The first use downloads three files (the font, the names' code points, the tags),
/// about 1.5 MB; after that everything loads from disk. Only an icon's SVG is fetched
/// on demand, when it's copied, and kept. Once a week, in the background, it asks
/// whether a newer Lucide came out and swaps it in once fully downloaded.
@Observable
final class LucideModel {
    enum Phase: Equatable {
        case idle
        /// Reading the cache from disk: quick, no spinner worth showing.
        case reading
        /// The first download, 0...1.
        case downloading(Double)
        case ready
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var index = LucideIndex(icons: [])
    /// The registered font's PostScript name; nil until the catalog is in.
    private(set) var fontName: String?
    /// Bumped when a newer Lucide replaces the font in place, so drawn glyphs redraw.
    private(set) var fontGeneration = 0
    private(set) var version: String?
    private(set) var recents: [LucideIcon] = []
    /// The search's matches, best first; empty while there's no query.
    private(set) var results: [LucideIcon] = []
    /// The icon whose SVG is on its way, for a spinner on its cell.
    private(set) var copying: String?
    var query = "" {
        didSet { if query != oldValue { updateResults() } }
    }

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var isCheckingForUpdate = false
    @ObservationIgnored private var fontURL: URL?
    @ObservationIgnored private var recentNames: [String]

    private static let recentsKey = "icons.recents"
    private static let versionKey = "icons.lucide.version"
    private static let checkedKey = "icons.lucide.checkedAt"

    init() {
        recentNames = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
    }

    var isLoaded: Bool { phase == .ready }
    var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var icons: [LucideIcon] { index.icons }

    // MARK: For the search launcher

    /// The best matches for `query`, or nothing while the catalog isn't loaded (asking
    /// starts loading it, so the next keystroke usually has it).
    func search(_ query: String, limit: Int) -> [LucideIcon] {
        if phase == .idle { warm() }
        guard isLoaded else { return [] }
        return index.search(query, limit: limit)
    }

    /// Starts loading without waiting for it.
    func warm() {
        guard loadTask == nil else { return }
        loadTask = Task { await run() }
    }

    // MARK: Loading

    func load() async {
        if loadTask == nil {
            warm()
        } else if isLoaded {
            checkForUpdate()
        }
        await loadTask?.value
    }

    func retry() {
        guard phase == .failed else { return }
        loadTask = nil
        warm()
    }

    private func run() async {
        phase = .reading
        let stored = UserDefaults.standard.string(forKey: Self.versionKey)
        let cached = await offMain { () -> LucideStore.Library? in
            var candidates = LucideStore.installedVersions()
            if let stored, let position = candidates.firstIndex(of: stored) {
                candidates.insert(candidates.remove(at: position), at: 0)
            }
            for version in candidates {
                if let library = LucideStore.read(version: version) { return library }
            }
            return nil
        }
        if let cached, await install(cached) {
            checkForUpdate()
            return
        }

        phase = .downloading(0)
        do {
            let latest = try await LucideStore.latestVersion()
            let library = try await LucideStore.download(version: latest) { fraction in
                Task { @MainActor [weak self] in self?.downloaded(fraction) }
            }
            UserDefaults.standard.set(Date.now, forKey: Self.checkedKey)
            if await install(library) { return }
        } catch {}
        phase = .failed
    }

    private func downloaded(_ fraction: Double) {
        // Chunks of the three files report out of order; the bar only moves forward.
        guard case .downloading(let shown) = phase, fraction > shown else { return }
        phase = .downloading(fraction)
    }

    /// Puts a version in use: registers its font (replacing the one before, if any) and
    /// shows its icons. False when the font won't register.
    private func install(_ library: LucideStore.Library) async -> Bool {
        let newURL = LucideStore.fontURL(in: library.folder)
        let oldURL = fontURL
        let name = await offMain { () -> String? in
            if let oldURL, oldURL != newURL { LucideStore.unregisterFont(at: oldURL) }
            if let name = LucideStore.registerFont(at: newURL) { return name }
            // Keep the old font working if the new one can't take its place.
            if let oldURL, oldURL != newURL { _ = LucideStore.registerFont(at: oldURL) }
            return nil
        }
        guard let name else { return false }

        let replacing = fontURL != nil
        fontURL = newURL
        fontName = name
        if replacing { fontGeneration += 1 }
        index = library.index
        version = library.version
        phase = .ready
        UserDefaults.standard.set(library.version, forKey: Self.versionKey)
        updateRecents()
        updateResults()

        let keep = library.version
        Task { await offMain { LucideStore.removeVersions(except: keep) } }
        return true
    }

    /// At most once a week: a newer Lucide downloads next to the current one, which stays
    /// in use until the new one is complete.
    private func checkForUpdate() {
        let lastChecked = UserDefaults.standard.object(forKey: Self.checkedKey) as? Date
        guard isLoaded, !isCheckingForUpdate, LucideSource.needsCheck(lastChecked: lastChecked) else { return }
        isCheckingForUpdate = true
        Task {
            defer { isCheckingForUpdate = false }
            // Offline now just means asking again on a later visit.
            guard let latest = try? await LucideStore.latestVersion() else { return }
            UserDefaults.standard.set(Date.now, forKey: Self.checkedKey)
            guard let current = version, LucideSource.isNewer(latest, than: current),
                  let library = try? await LucideStore.download(version: latest, progress: { _ in })
            else { return }
            _ = await install(library)
        }
    }

    // MARK: Copying

    /// Copies the icon's SVG, fetching it the first time. False when it couldn't be had
    /// (offline on an icon never copied before).
    @discardableResult
    func copySVG(_ icon: LucideIcon) async -> Bool {
        guard let version else { return false }
        copying = icon.name
        defer { if copying == icon.name { copying = nil } }
        guard let svg = try? await LucideStore.svg(for: icon.name, version: version) else { return false }
        put(svg, for: icon)
        return true
    }

    /// `arrow-right`
    func copyName(_ icon: LucideIcon) { put(icon.name, for: icon) }

    /// `<ArrowRight />`
    func copyJSX(_ icon: LucideIcon) { put(icon.jsx, for: icon) }

    /// `<i data-lucide="arrow-right"></i>`
    func copyHTML(_ icon: LucideIcon) { put(icon.htmlTag, for: icon) }

    func openPage(_ icon: LucideIcon) {
        NSWorkspace.shared.open(icon.pageURL)
    }

    private func put(_ text: String, for icon: LucideIcon) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Marked transient (nspasteboard.org), as the Emoji tab does: the tab keeps its
        // own recents, so clipboard histories don't fill up with every icon tried.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        recentNames = LucideRecents.record(icon.name, in: recentNames)
        UserDefaults.standard.set(recentNames, forKey: Self.recentsKey)
    }

    // MARK: Derived

    /// Shows the latest recents. Called when the tab appears, not on every copy, so the
    /// row doesn't reshuffle under the pointer.
    func updateRecents() {
        recents = recentNames.compactMap(index.icon(named:))
    }

    private func updateResults() {
        results = isSearching ? index.search(query) : []
    }
}
