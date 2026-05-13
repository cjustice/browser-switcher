// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BrowserSwitcher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BrowserSwitcher",
            path: "Sources/BrowserSwitcher",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.icns"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "SchedulerTests",
            dependencies: ["BrowserSwitcher"],
            path: "Tests/SchedulerTests"
        ),
    ]
)
