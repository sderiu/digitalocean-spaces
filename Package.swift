// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "DOSpaces",
    products: [
        .library(name: "DOSpaces", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/rausnitz/S3.git", .branch("master"))
    ],
    targets: [
        .target(name: "App", dependencies: ["S3Signer", "Vapor"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

