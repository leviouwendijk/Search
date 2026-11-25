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
    ],
    dependencies: [
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Tokens.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Matching.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Ranking.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Fuzzy.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Parsing.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Schema.git", branch: "master"),
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
