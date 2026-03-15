// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DialKit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DialKit",
            path: "Sources/DialKit",
            resources: [.copy("../../Resources/Info.plist")],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
