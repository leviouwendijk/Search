// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SearchTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
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
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Matching.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Parsing.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Schema.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/Testing.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "SearchTests",
            dependencies: [
                .product(name: "Search", package: "Search"),
                .product(name: "Matching", package: "Matching"),
                .product(name: "Position", package: "Position"),
                .product(name: "Parsing", package: "Parsing"),
                .product(name: "Testing", package: "Testing"),
            ]
        ),
        .executableTarget(
            name: "StructuredQueryTests",
            dependencies: [
                .product(name: "Search", package: "Search"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Primitives", package: "Primitives"),
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
