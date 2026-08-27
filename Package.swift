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
    targets: [
        .target(
            name: "Search"
        ),
    ],
    swiftLanguageModes: [.v6]
)
