// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Search",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Search",
            targets: ["Search"]
        ),
        .executable(
            name: "searchtest",
            targets: ["SearchTests"]
        ),
        .executable(
            name: "structuredquerytest",
            targets: ["StructuredQueryTests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Tokens.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Matching.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Ranking.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Fuzzy.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Parsing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Testing.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                .product(name: "Position", package: "Position"),
                .product(name: "Tokens", package: "Tokens"),
                .product(name: "Matching", package: "Matching"),
                .product(name: "Ranking", package: "Ranking"),
                .product(name: "Fuzzy", package: "Fuzzy"),
                .product(name: "Parsing", package: "Parsing"),
                .product(name: "Schema", package: "Schema"),
            ]
        ),
        .executableTarget(
            name: "SearchTests",
            dependencies: [
                "Search",
                .product(name: "Matching", package: "Matching"),
                .product(name: "Position", package: "Position"),
                .product(name: "Parsing", package: "Parsing"),
                .product(name: "Testing", package: "Testing"),
            ],
            path: "Testing/SearchTests"
        ),
        .executableTarget(
            name: "StructuredQueryTests",
            dependencies: [
                "Search",
                .product(name: "Schema", package: "Schema"),
                .product(name: "Primitives", package: "Primitives"),
            ],
            path: "Testing/StructuredQueryTests"
        ),
    ]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
