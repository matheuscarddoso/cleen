import Foundation

/// Build output and installed dependencies that a project recreates with one command.
public enum ArtifactKind: String, CaseIterable, Sendable, Hashable {
    case nodeModules
    case next
    case nuxt
    case turbo
    case svelteKit
    case parcelCache
    case angularCache
    case expo
    case composerVendor
    case cargoTarget
    case swiftBuild
    case cocoaPods
    case gradleBuild
    case gradleCache
    case flutterBuild
    case dartTool
    case derivedData
    case pythonVenv

    public var folderName: String {
        switch self {
        case .nodeModules: "node_modules"
        case .next: ".next"
        case .nuxt: ".nuxt"
        case .turbo: ".turbo"
        case .svelteKit: ".svelte-kit"
        case .parcelCache: ".parcel-cache"
        case .angularCache: ".angular"
        case .expo: ".expo"
        case .composerVendor: "vendor"
        case .cargoTarget: "target"
        case .swiftBuild: ".build"
        case .cocoaPods: "Pods"
        case .gradleBuild, .flutterBuild: "build"
        case .gradleCache: ".gradle"
        case .dartTool: ".dart_tool"
        case .derivedData: "DerivedData"
        case .pythonVenv: ".venv"
        }
    }

    public var title: String {
        switch self {
        case .nodeModules: "node_modules"
        case .next: "Build do Next.js"
        case .nuxt: "Build do Nuxt"
        case .turbo: "Cache do Turborepo"
        case .svelteKit: "Build do SvelteKit"
        case .parcelCache: "Cache do Parcel"
        case .angularCache: "Cache do Angular"
        case .expo: "Cache do Expo"
        case .composerVendor: "vendor do Composer"
        case .cargoTarget: "target do Cargo"
        case .swiftBuild: "Build do SwiftPM"
        case .cocoaPods: "Pods"
        case .gradleBuild: "Build do Gradle"
        case .gradleCache: "Cache do Gradle"
        case .flutterBuild: "Build do Flutter"
        case .dartTool: "Ferramentas do Dart"
        case .derivedData: "DerivedData"
        case .pythonVenv: "Ambiente virtual Python"
        }
    }

    /// The command that brings it back, shown so nobody deletes blind.
    public var restoreHint: String {
        switch self {
        case .nodeModules: "npm install"
        case .next, .nuxt, .svelteKit: "volta no próximo build"
        case .turbo, .parcelCache, .angularCache, .expo: "recriado automaticamente"
        case .composerVendor: "composer install"
        case .cargoTarget: "cargo build"
        case .swiftBuild: "swift build"
        case .cocoaPods: "pod install"
        case .gradleBuild, .gradleCache: "./gradlew build"
        case .flutterBuild, .dartTool: "flutter pub get"
        case .derivedData: "recriado pelo Xcode"
        case .pythonVenv: "python -m venv + pip install"
        }
    }

    /// A virtualenv can hold hand-installed packages; recreating it is not one command
    /// for everyone. Everything else is fair game once the project has gone quiet.
    public var selectedWhenStale: Bool { self != .pythonVenv }

    /// Files that must sit next to the folder for the name to mean what we think.
    /// `build`, `target` and `vendor` are too generic to trust on their own.
    var requiredSiblings: [String]? {
        switch self {
        case .composerVendor: ["composer.json"]
        case .cargoTarget: ["Cargo.toml"]
        case .swiftBuild: ["Package.swift"]
        case .cocoaPods: ["Podfile"]
        case .gradleBuild, .gradleCache: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]
        case .flutterBuild, .dartTool: ["pubspec.yaml"]
        case .next: ["next.config.js", "next.config.mjs", "next.config.ts", "package.json"]
        case .nuxt: ["nuxt.config.ts", "nuxt.config.js", "package.json"]
        case .svelteKit, .parcelCache, .angularCache, .expo, .turbo: ["package.json"]
        case .nodeModules, .derivedData, .pythonVenv: nil
        }
    }

    /// A file that must exist inside the folder.
    var requiredInside: String? {
        self == .pythonVenv ? "pyvenv.cfg" : nil
    }

    /// Which kind a folder is, given what sits beside it. `nil` for ordinary folders.
    static func match(folderName: String, parent: URL, fileExists: (URL) -> Bool) -> ArtifactKind? {
        let names = folderName == "venv" ? [".venv"] : [folderName]
        for kind in allCases where names.contains(kind.folderName) {
            if let siblings = kind.requiredSiblings,
               !siblings.contains(where: { fileExists(parent.appending(path: $0)) }) {
                continue
            }
            if let inside = kind.requiredInside,
               !fileExists(parent.appending(path: folderName).appending(path: inside)) {
                continue
            }
            return kind
        }
        return nil
    }
}
