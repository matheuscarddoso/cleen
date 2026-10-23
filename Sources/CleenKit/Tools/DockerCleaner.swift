import Foundation

public enum DockerCleaner {
    static let candidates = [
        "/opt/homebrew/bin/docker",
        "/usr/local/bin/docker",
        Paths.home.appending(path: ".orbstack/bin/docker").path(percentEncoded: false),
        "/Applications/Docker.app/Contents/Resources/bin/docker",
        "/Applications/OrbStack.app/Contents/MacOS/xbin/docker",
    ]

    static var executable: String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// What `docker system prune -a` would release. `nil` when Docker isn't installed or
    /// its engine isn't running — there is nothing Cleen could do either way.
    public static func inspect() async -> ToolCleanup? {
        guard let docker = executable,
              let result = try? await Shell.run(docker, ["system", "df", "--format", "{{json .}}"]),
              result.succeeded
        else { return nil }

        let rows = parseUsage(result.stdout)
        let reclaimable = rows.reduce(0) { $0 + $1.reclaimable }
        guard reclaimable > 0 else { return nil }

        let detail = rows
            .filter { $0.reclaimable > 0 }
            .map { "\($0.type): \($0.reclaimable.bytes)" }
            .joined(separator: " · ")
        return ToolCleanup(
            kind: .docker,
            title: "Docker",
            summary: String(localized: "Imagens sem uso, containers parados e cache de build. Volumes não são tocados."),
            symbol: "shippingbox.circle",
            reclaimable: reclaimable,
            detail: detail,
            selectedByDefault: false
        )
    }

    public static func clean() async throws {
        guard let docker = executable else { return }
        let result = try await Shell.run(docker, ["system", "prune", "--all", "--force"])
        guard result.succeeded else { throw ShellError.failed(result) }
    }

    struct UsageRow: Equatable {
        let type: String
        let reclaimable: Int64
    }

    static func parseUsage(_ output: String) -> [UsageRow] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["Type"] as? String,
                  let reclaimable = object["Reclaimable"] as? String
            else { return nil }
            return UsageRow(type: localized(type), reclaimable: parseSize(reclaimable))
        }
    }

    /// Docker prints sizes like `1.204GB (50%)` in decimal units.
    static func parseSize(_ text: String) -> Int64 {
        let token = text.split(separator: " ").first.map(String.init) ?? text
        let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1)]
        for (suffix, multiplier) in units where token.hasSuffix(suffix) {
            guard let value = Double(token.dropLast(suffix.count)) else { return 0 }
            return Int64(value * multiplier)
        }
        return 0
    }

    private static func localized(_ type: String) -> String {
        switch type {
        case "Images": String(localized: "Imagens")
        case "Containers": String(localized: "Containers")
        case "Local Volumes": String(localized: "Volumes")
        case "Build Cache": String(localized: "Cache de build")
        default: type
        }
    }
}
