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
            targets: ["SearchTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Tokens.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Matching.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Ranking.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Fuzzy.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Parsing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),
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
            ]
        ),
        .executableTarget(
            name: "SearchTestFlows",
            dependencies: [
                "Search",
                .product(name: "Matching", package: "Matching"),
                .product(name: "Position", package: "Position"),
                .product(name: "Parsing", package: "Parsing"),
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
)
