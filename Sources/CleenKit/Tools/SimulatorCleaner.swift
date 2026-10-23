import Foundation

/// Simulators whose runtime is gone (left behind by Xcode updates). They can't boot
/// anymore, yet each keeps its whole disk image.
public enum SimulatorCleaner {
    public static func inspect(home: URL = Paths.home) async -> ToolCleanup? {
        // Without Xcode, /usr/bin/xcrun is only a stub that offers to install the
        // developer tools, so it's never called unless there are simulators at all.
        let root = home.appending(path: "Library/Developer/CoreSimulator/Devices")
        guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)),
              FileManager.default.isExecutableFile(atPath: "/usr/bin/xcrun"),
              let result = try? await Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "unavailable", "--json"]),
              result.succeeded
        else { return nil }

        let devices = parseUnavailable(result.stdout)
        guard !devices.isEmpty else { return nil }

        let size = await BlockingIO.run {
            devices.reduce(Int64(0)) { total, udid in total + FileSizer.allocatedSize(of: root.appending(path: udid)) }
        }
        guard size > 0 else { return nil }

        return ToolCleanup(
            kind: .simulators,
            title: "Simuladores sem runtime",
            summary: "Simuladores de versões do iOS que o Xcode não tem mais. Não abrem e ocupam espaço.",
            symbol: "iphone.slash",
            reclaimable: size,
            detail: devices.count == 1 ? "1 simulador" : "\(devices.count) simuladores",
            selectedByDefault: true
        )
    }

    public static func clean() async throws {
        let result = try await Shell.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])
        guard result.succeeded else { throw ShellError.failed(result) }
    }

    /// UDIDs from `simctl list devices unavailable --json`.
    static func parseUnavailable(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtimes = object["devices"] as? [String: [[String: Any]]]
        else { return [] }
        return runtimes.values.flatMap { $0 }.compactMap { device in
            (device["isAvailable"] as? Bool) == false ? device["udid"] as? String : nil
        }
    }
}
