// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpiderSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        // Only the client is a product. The generated wire models (SpiderContract) are an internal target,
        // so downstream packages cannot import them — the same encapsulation the Kotlin SDK gets from `internal`.
        .library(name: "SpiderSDK", targets: ["SpiderSDK"]),
    ],
    targets: [
        .target(name: "SpiderContract"),
        .target(name: "SpiderSDK", dependencies: ["SpiderContract"]),
        .testTarget(name: "SpiderSDKTests", dependencies: ["SpiderSDK"]),
        // Region-tagged example programs the docs site inlines as code samples. Not a package product
        // (internal, like the tests); it exists only to keep the samples compiling against the real API.
        .executableTarget(name: "spider-sdk-examples", dependencies: ["SpiderSDK"], path: "Sources/Examples"),
    ]
)
