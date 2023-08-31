// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "core-data-publisher",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "CoreDataPublisher",
            targets: ["CoreDataPublisher"]
        ),
    ],
    targets: [
        .target(
            name: "CoreDataPublisher"),
        .testTarget(
            name: "CoreDataPublisherTests",
            dependencies: ["CoreDataPublisher"]
        ),
    ]
)
