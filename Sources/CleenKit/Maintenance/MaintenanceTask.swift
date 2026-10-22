import Foundation

/// One-off system chores. Each one maps to a documented macOS command; nothing here
/// writes into system folders by hand.
public enum MaintenanceTask: String, CaseIterable, Sendable, Identifiable {
    case freeMemory
    case thinSnapshots
    case flushDNS
    case reindexSpotlight
    case rebuildLaunchServices
    case resetFontCache
    case verifyDisk

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .freeMemory: "Liberar memória"
        case .thinSnapshots: "Liberar espaço reservado"
        case .flushDNS: "Limpar cache de DNS"
        case .reindexSpotlight: "Reindexar o Spotlight"
        case .rebuildLaunchServices: "Reconstruir o menu Abrir Com"
        case .resetFontCache: "Limpar cache de fontes"
        case .verifyDisk: "Verificar o disco"
        }
    }

    public var summary: String {
        switch self {
        case .freeMemory:
            "Esvazia o cache de arquivos da memória. Útil antes de abrir algo pesado, o macOS volta a encher sozinho."
        case .thinSnapshots:
            "Apaga os snapshots locais do Time Machine, que seguram espaço apagado como \u{201C}purgeable\u{201D}. Os backups no disco externo não são tocados."
        case .flushDNS:
            "Resolve sites que não abrem depois de trocar de rede, VPN ou DNS."
        case .reindexSpotlight:
            "Recria o índice de busca do zero. Use quando o Spotlight não acha arquivos que existem. Leva alguns minutos."
        case .rebuildLaunchServices:
            "Remove apps duplicados ou que já não existem do menu Abrir Com."
        case .resetFontCache:
            "Corrige fontes que aparecem quebradas ou trocadas. Reinicie o Mac depois."
        case .verifyDisk:
            "Confere a estrutura do disco sem alterar nada. Pode levar alguns minutos."
        }
    }

    public var symbol: String {
        switch self {
        case .freeMemory: "memorychip"
        case .thinSnapshots: "clock.arrow.circlepath"
        case .flushDNS: "network"
        case .reindexSpotlight: "magnifyingglass"
        case .rebuildLaunchServices: "square.grid.3x3"
        case .resetFontCache: "textformat"
        case .verifyDisk: "internaldrive"
        }
    }

    public var needsAdministrator: Bool {
        switch self {
        case .freeMemory, .flushDNS, .reindexSpotlight: true
        case .thinSnapshots, .rebuildLaunchServices, .resetFontCache, .verifyDisk: false
        }
    }

    /// Runs the task and returns a one-line result for the person.
    public func run() async throws -> String {
        switch self {
        case .freeMemory:
            // purge drops the file cache, so that's where the difference shows.
            let before = MemoryStats.read()?.cached ?? 0
            _ = try await Shell.runAsAdministrator("/usr/sbin/purge")
            let after = MemoryStats.read()?.cached ?? before
            let freed = max(0, before - after)
            return freed > 0 ? "\(freed.memoryBytes) liberados." : "Memória já estava enxuta."

        case .thinSnapshots:
            let before = await Self.localSnapshotCount()
            guard before > 0 else { return "Não havia snapshots locais." }
            let arguments = ["thinlocalsnapshots", "/", "999999999999", "4"]
            let result = try await Shell.run("/usr/bin/tmutil", arguments)
            if !result.succeeded {
                _ = try await Shell.runAsAdministrator("/usr/bin/tmutil " + arguments.joined(separator: " "))
            }
            let removed = before - (await Self.localSnapshotCount())
            return removed == 1 ? "1 snapshot removido." : "\(removed) snapshots removidos."

        case .flushDNS:
            _ = try await Shell.runAsAdministrator("/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder")
            return "Cache de DNS limpo."

        case .reindexSpotlight:
            _ = try await Shell.runAsAdministrator("/usr/bin/mdutil -E /")
            return "O Spotlight começou a reindexar. A busca volta completa em alguns minutos."

        case .rebuildLaunchServices:
            let tool = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            let result = try await Shell.run(tool, ["-r", "-domain", "local", "-domain", "system", "-domain", "user"])
            guard result.succeeded else { throw ShellError.failed(result) }
            return "Lista de apps reconstruída."

        case .resetFontCache:
            let result = try await Shell.run("/usr/bin/atsutil", ["databases", "-removeUser"])
            guard result.succeeded else { throw ShellError.failed(result) }
            return "Cache de fontes limpo. Reinicie o Mac para concluir."

        case .verifyDisk:
            let result = try await Shell.run("/usr/sbin/diskutil", ["verifyVolume", "/"])
            guard result.succeeded else { throw ShellError.failed(result) }
            return "Disco verificado, nenhum problema encontrado."
        }
    }

    public static func localSnapshotCount() async -> Int {
        guard let result = try? await Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]), result.succeeded else { return 0 }
        return result.stdout.split(whereSeparator: \.isNewline).count { $0.contains("com.apple.TimeMachine") }
    }
}
