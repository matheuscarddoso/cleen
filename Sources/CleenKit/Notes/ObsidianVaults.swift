import Foundation

/// The vaults Obsidian knows about, read from its own list
/// (`~/Library/Application Support/obsidian/obsidian.json`): so picking one is a click,
/// not a hunt through the Finder.
public enum ObsidianVaults {
    public struct Vault: Sendable, Equatable, Identifiable {
        public var id: String { path }
        public let path: String
        /// The folder's name, as Obsidian shows it.
        public var name: String { URL(filePath: path).lastPathComponent }
        public let lastOpened: Date?
    }

    public static func list(home: URL = Paths.home) -> [Vault] {
        let file = home.appending(path: "Library/Application Support/obsidian/obsidian.json")
        guard let data = try? Data(contentsOf: file) else { return [] }
        return parse(data).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// `{"vaults": {"<id>": {"path": "/…", "ts": 1773864841555, "open": true}}}`, the
    /// one opened last first.
    static func parse(_ data: Data) -> [Vault] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vaults = object["vaults"] as? [String: Any]
        else { return [] }
        return vaults.values.compactMap { value -> Vault? in
            guard let vault = value as? [String: Any], let path = vault["path"] as? String, !path.isEmpty else { return nil }
            let opened = (vault["ts"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
            return Vault(path: path, lastOpened: opened)
        }
        .sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
    }
}
