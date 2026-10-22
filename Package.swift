// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Lustro",
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Lustro", targets: ["Lustro"])
    ],
    targets: [
        // Everything that touches the file system or the kernel lives here, free of UI,
        // so it can be tested against temporary directories.
        .target(
            name: "LustroKit",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Lustro",
            dependencies: ["LustroKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "LustroKitTests",
            dependencies: ["LustroKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
