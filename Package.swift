// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIComponents",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(name: "SwiftUIComponents",
                 targets: ["SwiftUIComponents"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ivkuznetsov/CommonUtils.git", from: .init(1, 1, 3)),
        .package(url: "https://github.com/ivkuznetsov/Coordinators.git", from: .init(1, 0, 0))
    ],
    targets: [
        .target(name: "SwiftUIComponents",
                dependencies: ["CommonUtils", "Coordinators"])
    ]
)
