import Foundation

/// Turns launchd jobs off and on. Disabling is the default suggestion because it's
/// fully reversible: launchd keeps an override and the plist stays where it was.
public enum LaunchControl {
    static func domain(for scope: LaunchItem.Scope) -> String {
        scope == .system ? "system" : "gui/\(getuid())"
    }

    public static func disable(_ item: LaunchItem) async throws {
        let target = "\(domain(for: item.scope))/\(item.label)"
        if item.scope == .system {
            _ = try await Shell.runAsAdministrator(
                "/bin/launchctl disable \(Shell.quote(target)); /bin/launchctl bootout \(Shell.quote(target)) || true"
            )
        } else {
            let result = try await Shell.run("/bin/launchctl", ["disable", target])
            guard result.succeeded else { throw ShellError.failed(result) }
            _ = try? await Shell.run("/bin/launchctl", ["bootout", target])
        }
    }

    public static func enable(_ item: LaunchItem) async throws {
        let domain = domain(for: item.scope)
        let target = "\(domain)/\(item.label)"
        let plist = item.plist.path(percentEncoded: false)
        if item.scope == .system {
            _ = try await Shell.runAsAdministrator(
                "/bin/launchctl enable \(Shell.quote(target)); /bin/launchctl bootstrap \(domain) \(Shell.quote(plist)) || true"
            )
        } else {
            let result = try await Shell.run("/bin/launchctl", ["enable", target])
            guard result.succeeded else { throw ShellError.failed(result) }
            _ = try? await Shell.run("/bin/launchctl", ["bootstrap", domain, plist])
        }
    }

    /// Stops the job and moves its plist to the Trash.
    public static func remove(_ item: LaunchItem, remover: FileRemover = .standard) async -> RemovalOutcome {
        let request = RemovalRequest(url: item.plist, size: 0, mode: .trash)
        let target = "\(domain(for: item.scope))/\(item.label)"
        if item.scope == .user {
            _ = try? await Shell.run("/bin/launchctl", ["bootout", target])
            return await remover.remove([request])
        }
        if item.scope == .allUsers {
            _ = try? await Shell.run("/bin/launchctl", ["bootout", target])
        }
        return await remover.removeAsAdministrator(
            [request],
            preamble: item.scope == .system ? "/bin/launchctl bootout \(Shell.quote(target)) || true" : nil
        )
    }

    /// Labels with a "disabled" override in a domain.
    public static func disabledLabels(scope: LaunchItem.Scope) async -> Set<String> {
        guard let result = try? await Shell.run("/bin/launchctl", ["print-disabled", domain(for: scope)]),
              result.succeeded
        else { return [] }
        return parseDisabled(result.stdout)
    }

    /// Lines look like `"com.example.agent" => disabled` (or `=> true` on older systems).
    static func parseDisabled(_ output: String) -> Set<String> {
        var labels = Set<String>()
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=>").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, parts[1] == "disabled" || parts[1] == "true" else { continue }
            labels.insert(parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
        }
        return labels
    }
}
