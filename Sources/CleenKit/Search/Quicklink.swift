import Foundation

/// A web address with a slot for what's typed, Raycast's Quicklinks: `gh cleen` opens
/// GitHub's search for "cleen". Without `{query}` it just opens the address.
public struct Quicklink: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// What's typed before the query: "gh", "yt". Empty: found by name only.
    public var keyword: String
    /// `https://github.com/search?q={query}`.
    public var url: String

    public init(id: UUID = UUID(), name: String, keyword: String, url: String) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.url = url
    }

    public static let placeholder = "{query}"

    public var takesQuery: Bool { url.contains(Self.placeholder) }

    /// The address with the query in its slot, encoded for a URL. nil when the template
    /// isn't a web address, or it needs a query and none was given.
    public func url(for query: String) -> URL? {
        let query = query.trimmingCharacters(in: .whitespaces)
        if takesQuery && query.isEmpty { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#/")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        let address = url.replacingOccurrences(of: Self.placeholder, with: encoded)
        guard let result = URL(string: address), let scheme = result.scheme?.lowercased(), Self.allowedSchemes.contains(scheme) else { return nil }
        return result
    }

    /// Web pages and the apps that open from links; never `file:` or scripts.
    static let allowedSchemes: Set<String> = ["http", "https", "mailto", "spotify", "slack", "zoommtg", "obsidian", "notion", "raycast", "things", "x-apple.systempreferences"]

    /// "gh cleen" → the GitHub link and "cleen", when "gh" is a keyword.
    public static func match(_ text: String, in links: [Quicklink]) -> (link: Quicklink, query: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let head = trimmed.prefix { !$0.isWhitespace }
        let rest = trimmed.dropFirst(head.count).trimmingCharacters(in: .whitespaces)
        let key = FuzzyMatch.fold(String(head))
        guard !key.isEmpty, let link = links.first(where: { !$0.keyword.isEmpty && FuzzyMatch.fold($0.keyword) == key }) else { return nil }
        return (link, rest)
    }

    /// What a new install starts with; editable in Ajustes › Busca.
    public static let defaults: [Quicklink] = [
        Quicklink(name: "Google", keyword: "g", url: "https://www.google.com/search?q={query}"),
        Quicklink(name: "YouTube", keyword: "yt", url: "https://www.youtube.com/results?search_query={query}"),
        Quicklink(name: "GitHub", keyword: "gh", url: "https://github.com/search?q={query}"),
        Quicklink(name: "Google Maps", keyword: "maps", url: "https://www.google.com/maps/search/{query}"),
        Quicklink(name: String(localized: "Google Tradutor"), keyword: "tr", url: "https://translate.google.com/?sl=auto&tl=pt&text={query}"),
        Quicklink(name: "Wikipedia", keyword: "wiki", url: "https://pt.wikipedia.org/w/index.php?search={query}"),
    ]
}

/// Something typed that is already an address: `github.com/foo`, `https://x.com`.
public enum WebAddress {
    public static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: trimmed).flatMap { $0.host() == nil ? nil : $0 }
        }
        // A host with a dot and a top-level domain of letters: "cleen.ocardoso.com".
        let host = lower.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }),
              let tld = labels.last, tld.count >= 2, tld.allSatisfy(\.isLetter)
        else {
            // "localhost:3000".
            if host.hasPrefix("localhost:"), Int(host.dropFirst("localhost:".count)) != nil { return URL(string: "http://" + trimmed) }
            return nil
        }
        // "1.5" or "file.txt" aren't addresses: the domain must be a known-looking one.
        guard !Self.fileExtensions.contains(String(tld)) else { return nil }
        return URL(string: "https://" + trimmed)
    }

    /// File names typed into the search look like hosts; these endings aren't domains.
    static let fileExtensions: Set<String> = ["txt", "md", "pdf", "png", "jpg", "jpeg", "gif", "swift", "js", "ts", "tsx", "json", "csv", "zip", "dmg", "pkg", "app", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages", "numbers", "mov", "mp4", "mp3", "html", "css", "py", "rb", "sh", "log", "plist", "yml", "yaml", "heic", "svg", "webp"]
}
