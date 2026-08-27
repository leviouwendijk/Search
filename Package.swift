// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Search",
    products: [
        .library(
            name: "Search",
            targets: ["Search"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Fuzzy.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Matching.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Ranking.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                .product(
                    name: "Fuzzy",
                    package: "Fuzzy"
                ),
                .product(
                    name: "Matching",
                    package: "Matching"
                ),
                .product(
                    name: "Ranking",
                    package: "Ranking"
                ),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
