// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DrownedCore",
    platforms: [.macOS(.v14)],          // add .iOS(.v17) when the iOS shell lands
    products: [
        .library(name: "DrownedModel",  targets: ["DrownedModel"]),
        .library(name: "DrownedStore",  targets: ["DrownedStore"]),
        .library(name: "DrownedSync",   targets: ["DrownedSync"]),
        .library(name: "DrownedNotify", targets: ["DrownedNotify"]),
        .library(name: "DrownedUI",     targets: ["DrownedUI"]),
    ],
    dependencies: [
        // Plain GRDB (no SQLCipher — data is public, plan §2.3).
        // GRDB 7 brings Swift 6 / strict-concurrency support. Verify latest tag.
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(name: "DrownedModel"),
        .target(
            name: "DrownedStore",
            dependencies: [
                "DrownedModel",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(name: "DrownedSync",   dependencies: ["DrownedModel", "DrownedStore"]),
        .target(name: "DrownedNotify", dependencies: ["DrownedModel"]),
        .target(
            name: "DrownedUI",
            dependencies: [
                "DrownedModel",
                "DrownedStore",
                "DrownedSync",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),

        .testTarget(name: "DrownedModelTests", dependencies: ["DrownedModel"]),
        .testTarget(name: "DrownedStoreTests", dependencies: ["DrownedStore"]),
        .testTarget(
            name: "DrownedSyncTests",
            dependencies: ["DrownedSync"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
