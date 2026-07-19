// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BypassRouter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BypassRouter",
            path: "Sources/BypassRouter",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .testTarget(name: "BypassRouterTests", dependencies: ["BypassRouter"])
    ]
)
