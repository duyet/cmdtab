// swift-tools-version: 6.0
// Xcode IDE entry point only — canonical builds remain ./build.sh, ./test.sh,
// ./build_ios.sh (raw swiftc; they embed Info.plist and ad-hoc sign the bundle).
// Open this file in Xcode to get the full IDE (indexing, debugger, previews).
import PackageDescription

let package = Package(
    name: "MinhAgent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MinhAgent",
            path: "Sources",
            exclude: ["iOS"],
            swiftSettings: [
                .define("DISABLE_NATIVE_LLM")
            ]
        )
    ]
)
