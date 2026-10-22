import Foundation

/// Everything Lustro knows how to clean, and what it deliberately leaves alone.
///
/// Rules of the catalog:
/// - `.delete` only for data the owner regenerates by itself (caches, logs, build output).
/// - Anything someone could want back goes to the Trash and starts unselected.
/// - Specific sources win over generic ones: `~/Library/Caches/Homebrew` is reported
///   under "Gerenciadores de pacotes", never also under "Caches de apps".
public enum JunkCatalog {
    public static let all: [JunkCategory] = [
        appCaches, logs, trash, installers, mailDownloads, deviceUpdates, deviceBackups,
        xcode, xcodeArchives, packageManagers, testBrowsers,
        browserCaches,
    ]

    // MARK: Sistema

    static let appCaches = JunkCategory(
        id: "app-caches",
        title: "Caches de apps",
        summary: "Arquivos temporários que os apps recriam quando precisam.",
        symbol: "shippingbox",
        group: .system,
        sources: [.contents(of: "~/Library/Caches")],
        excludedNames: [
            // iCloud, Apple ID, Wallet, Home, Find My, App Store and in-flight downloads
            // keep state here that is expensive or unsafe to rebuild.
            "CloudKit", "FamilyCircle", "familycircled", "GameKit", "PassKit",
            "com.apple.akd", "com.apple.amsaccountsd", "com.apple.ap.adprivacyd",
            "com.apple.appleaccountd", "com.apple.appstoreagent", "com.apple.bird",
            "com.apple.cache_delete", "com.apple.commerce", "com.apple.containermanagerd",
            "com.apple.findmy.findmylocateagent", "com.apple.HomeKit", "com.apple.homed",
            "com.apple.iCloudNotificationAgent", "com.apple.icloudmailagent",
            "com.apple.nsurlsessiond", "com.apple.passd", "com.apple.Safari.SafeBrowsing",
            "com.apple.storekitagent", "app.lustro.Lustro",
        ]
    )

    static let logs = JunkCategory(
        id: "logs",
        title: "Logs",
        summary: "Registros de apps e relatórios de travamento antigos.",
        symbol: "doc.text",
        group: .system,
        sources: [.contents(of: "~/Library/Logs")]
    )

    static let trash = JunkCategory(
        id: "trash",
        title: "Lixeira",
        summary: "O que já está no Lixo continua ocupando espaço até ser esvaziado.",
        symbol: "trash",
        group: .system,
        sources: [.contents(of: "~/.Trash")],
        needsFullDiskAccess: true,
        excludedNames: [".DS_Store"]
    )

    static let installers = JunkCategory(
        id: "installers",
        title: "Instaladores baixados",
        summary: "Arquivos .dmg, .pkg e .zip de apps que normalmente já foram instalados.",
        symbol: "arrow.down.app",
        group: .system,
        sources: [
            .files(in: "~/Downloads", extensions: ["dmg", "pkg", "mpkg", "xip"]),
            .files(in: "~/Desktop", extensions: ["dmg", "pkg", "mpkg", "xip"]),
            .files(in: "/Applications", extensions: ["dmg", "pkg"]),
        ],
        removal: .trash
    )

    static let mailDownloads = JunkCategory(
        id: "mail-downloads",
        title: "Anexos abertos no Mail",
        summary: "Cópias de anexos que o Mail guarda ao abrir. O e-mail original continua intacto.",
        symbol: "paperclip",
        group: .system,
        sources: [.contents(of: "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads")],
        needsFullDiskAccess: true
    )

    static let deviceUpdates = JunkCategory(
        id: "device-updates",
        title: "Atualizações de iPhone e iPad",
        summary: "Arquivos de sistema baixados para atualizar aparelhos. São baixados de novo quando preciso.",
        symbol: "iphone.gen3",
        group: .system,
        sources: [
            .contents(of: "~/Library/iTunes/iPhone Software Updates"),
            .contents(of: "~/Library/iTunes/iPad Software Updates"),
        ]
    )

    static let deviceBackups = JunkCategory(
        id: "device-backups",
        title: "Backups de iPhone e iPad",
        summary: "Backups locais de aparelhos. Vão para o Lixo, confira antes de esvaziar.",
        symbol: "externaldrive.badge.timemachine",
        group: .system,
        sources: [.contents(of: "~/Library/Application Support/MobileSync/Backup")],
        removal: .trash,
        selectedByDefault: false,
        needsFullDiskAccess: true
    )

    // MARK: Desenvolvimento

    static let xcode = JunkCategory(
        id: "xcode",
        title: "Xcode",
        summary: "DerivedData, previews, caches do simulador e símbolos de aparelhos.",
        symbol: "hammer",
        group: .developer,
        sources: [
            .whole("~/Library/Developer/Xcode/DerivedData", label: "DerivedData"),
            .whole("~/Library/Developer/Xcode/UserData/Previews", label: "Previews do SwiftUI"),
            .whole("~/Library/Developer/CoreSimulator/Caches", label: "Caches do Simulador"),
            .whole("~/Library/Developer/Xcode/DocumentationCache", label: "Cache da documentação"),
            .whole("~/Library/Caches/com.apple.dt.Xcode", label: "Cache do Xcode", bundleID: "com.apple.dt.Xcode"),
            .contents(of: "~/Library/Developer/Xcode/iOS DeviceSupport"),
            .contents(of: "~/Library/Developer/Xcode/watchOS DeviceSupport"),
            .contents(of: "~/Library/Developer/Xcode/tvOS DeviceSupport"),
            .contents(of: "~/Library/Developer/Xcode/visionOS DeviceSupport"),
            .contents(of: "~/Library/Developer/Xcode/macOS DeviceSupport"),
        ]
    )

    static let xcodeArchives = JunkCategory(
        id: "xcode-archives",
        title: "Archives do Xcode",
        summary: "Builds enviados para a App Store. Guardam os símbolos para ler crashes de versões publicadas.",
        symbol: "archivebox",
        group: .developer,
        sources: [.contents(of: "~/Library/Developer/Xcode/Archives")],
        removal: .trash,
        selectedByDefault: false
    )

    static let packageManagers = JunkCategory(
        id: "package-managers",
        title: "Gerenciadores de pacotes",
        summary: "Pacotes baixados por npm, Composer, Homebrew e afins. Voltam no próximo install.",
        symbol: "cube.box",
        group: .developer,
        sources: [
            .whole("~/.npm/_cacache", label: "npm"),
            .whole("~/.npm/_npx", label: "npx"),
            .whole("~/Library/Caches/Yarn", label: "Yarn"),
            .whole("~/Library/Caches/pnpm", label: "pnpm"),
            .whole("~/.bun/install/cache", label: "Bun"),
            .whole("~/Library/Caches/deno", label: "Deno"),
            .whole("~/Library/Caches/composer", label: "Composer"),
            .whole("~/.composer/cache", label: "Composer (pasta antiga)"),
            .whole("~/Library/Caches/Homebrew", label: "Homebrew"),
            .whole("~/Library/Caches/pip", label: "pip"),
            .whole("~/Library/Caches/CocoaPods", label: "CocoaPods"),
            .whole("~/Library/Caches/org.swift.swiftpm", label: "Swift Package Manager"),
            .whole("~/Library/Caches/go-build", label: "Go"),
            .whole("~/.cargo/registry/cache", label: "Cargo"),
            .whole("~/.gradle/caches", label: "Gradle"),
            .whole("~/Library/Caches/node-gyp", label: "node-gyp"),
            .whole("~/Library/Caches/typescript", label: "TypeScript"),
            .whole("~/Library/Caches/electron", label: "Electron"),
            .whole("~/Library/Caches/electron-builder", label: "electron-builder"),
            .whole("~/Library/Caches/prisma-nodejs", label: "Prisma"),
        ]
    )

    static let testBrowsers = JunkCategory(
        id: "test-browsers",
        title: "Navegadores de teste",
        summary: "Navegadores do Playwright, Cypress e Puppeteer. Baixados de novo no próximo teste.",
        symbol: "testtube.2",
        group: .developer,
        sources: [
            .whole("~/Library/Caches/ms-playwright", label: "Playwright"),
            .whole("~/Library/Caches/Cypress", label: "Cypress"),
            .whole("~/.cache/puppeteer", label: "Puppeteer"),
        ],
        selectedByDefault: false
    )

    // MARK: Navegadores

    static let browserCaches = JunkCategory(
        id: "browser-caches",
        title: "Cache de navegadores",
        summary: "Páginas e imagens guardadas pelos navegadores. Senhas, abas e histórico não são tocados.",
        symbol: "globe",
        group: .browsers,
        sources: [
            .whole("~/Library/Caches/Google/Chrome", label: "Chrome", bundleID: "com.google.Chrome"),
            .whole("~/Library/Caches/Arc", label: "Arc", bundleID: "company.thebrowser.Browser"),
            .whole("~/Library/Caches/Dia", label: "Dia", bundleID: "company.thebrowser.dia"),
            .whole("~/Library/Caches/company.thebrowser.dia", label: "Dia (sistema)", bundleID: "company.thebrowser.dia"),
            .whole("~/Library/Caches/zen", label: "Zen", bundleID: "app.zen-browser.zen"),
            .whole("~/Library/Caches/Firefox", label: "Firefox", bundleID: "org.mozilla.firefox"),
            .whole("~/Library/Caches/Mozilla", label: "Firefox (sistema)", bundleID: "org.mozilla.firefox"),
            .whole("~/Library/Caches/BraveSoftware", label: "Brave", bundleID: "com.brave.Browser"),
            .whole("~/Library/Caches/Microsoft Edge", label: "Edge", bundleID: "com.microsoft.edgemac"),
            .whole("~/Library/Caches/com.operasoftware.Opera", label: "Opera", bundleID: "com.operasoftware.Opera"),
            .whole("~/Library/Caches/Vivaldi", label: "Vivaldi", bundleID: "com.vivaldi.Vivaldi"),
            .whole("~/Library/Caches/com.apple.Safari", label: "Safari", bundleID: "com.apple.Safari"),
        ]
    )
}
