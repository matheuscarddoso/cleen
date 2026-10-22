// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Cleen",
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Cleen", targets: ["Cleen"])
    ],
    targets: [
        // Everything that touches the file system or the kernel lives here, free of UI,
        // so it can be tested against temporary directories.
        .target(
            name: "CleenKit",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Cleen",
            dependencies: ["CleenKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "CleenKitTests",
            dependencies: ["CleenKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
