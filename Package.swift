// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "DOSpaces",
    products: [
        .library(name: "DOSpaces", targets: ["DOSpaces"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/rausnitz/S3.git", .branch("master")),
        .package(url: "https://github.com/drmohundro/SWXMLHash.git", from: "5.0.0")
    ],
    targets: [
        .target(name: "DOSpaces", dependencies: ["S3Signer", "Vapor", "SWXMLHash"])
    ]
)

