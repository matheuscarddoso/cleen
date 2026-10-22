import Foundation

public struct LaunchItemScanner: Sendable {
    let home: URL
    let systemLibrary: URL

    public init(home: URL = Paths.home, systemLibrary: URL = URL(filePath: "/Library")) {
        self.home = home
        self.systemLibrary = systemLibrary
    }

    public func scan() async -> [LaunchItem] {
        let loadedUser = await Self.loadedLabels(domain: "gui/\(getuid())")
        let loadedSystem = await Self.loadedLabels(domain: "system")
        let disabledUser = await LaunchControl.disabledLabels(scope: .user)
        let disabledSystem = await LaunchControl.disabledLabels(scope: .system)

        let folders: [(URL, LaunchItem.Scope)] = [
            (home.appending(path: "Library/LaunchAgents"), .user),
            (systemLibrary.appending(path: "LaunchAgents"), .allUsers),
            (systemLibrary.appending(path: "LaunchDaemons"), .system),
        ]
        var items: [LaunchItem] = []
        for (folder, scope) in folders {
            let plists = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for plist in plists where plist.pathExtension == "plist" {
                let loaded = scope == .system ? loadedSystem : loadedUser
                let disabled = scope == .system ? disabledSystem : disabledUser
                if let item = Self.parse(plist, scope: scope, loaded: loaded, disabled: disabled) { items.append(item) }
            }
        }
        return items.sorted { lhs, rhs in
            if lhs.signature.isSuspicious != rhs.signature.isSuspicious { return lhs.signature.isSuspicious }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func parse(_ plist: URL, scope: LaunchItem.Scope, loaded: Set<String>, disabled: Set<String>) -> LaunchItem? {
        guard let data = try? Data(contentsOf: plist),
              let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let label = dictionary["Label"] as? String
        else { return nil }

        let arguments = dictionary["ProgramArguments"] as? [String] ?? []
        let programPath = (dictionary["Program"] as? String) ?? arguments.first
        let program = programPath.map { URL(filePath: ($0 as NSString).expandingTildeInPath) }
        let keepAlive: Bool = switch dictionary["KeepAlive"] {
        case let flag as Bool: flag
        case is [String: Any]: true
        default: false
        }

        return LaunchItem(
            plist: plist,
            label: label,
            program: program,
            arguments: arguments,
            scope: scope,
            runsAtLoad: dictionary["RunAtLoad"] as? Bool ?? false,
            keepsAlive: keepAlive,
            isDisabled: (dictionary["Disabled"] as? Bool ?? false) || disabled.contains(label),
            isLoaded: loaded.contains(label),
            signature: program.map(CodeSignature.status(of:)) ?? .missing
        )
    }

    /// Labels of the services launchd currently has loaded in a domain.
    static func loadedLabels(domain: String) async -> Set<String> {
        guard let result = try? await Shell.run("/bin/launchctl", ["print", domain]), result.succeeded else { return [] }
        return parseServices(result.stdout)
    }

    /// Pulls labels out of the `services = { ... }` block of `launchctl print`.
    static func parseServices(_ output: String) -> Set<String> {
        var labels = Set<String>()
        var inServices = false
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "services = {" {
                inServices = true
                continue
            }
            guard inServices else { continue }
            if trimmed == "}" { break }
            // Lines look like: `  0   -   com.example.agent` (pid, last exit, label).
            if let label = trimmed.split(whereSeparator: \.isWhitespace).last {
                labels.insert(String(label))
            }
        }
        return labels
    }
}
