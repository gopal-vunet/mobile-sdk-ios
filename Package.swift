// swift-tools-version: 6.1
// vuTelemetry v0.0.4 — pre-built binary package. See README.md.
// Built WITH library evolution: portable .swiftinterface, consumable by any Xcode >= Xcode 26.5.
import PackageDescription

let package = Package(
    name: "vuTelemetry",
    platforms: [.iOS(.v13), .macOS(.v12)],
    products: [
        .library(name: "vuTelemetry", targets: ["vuTelemetry", "VuTelemetryBootstrap", "vuTelemetryDeps"]),
        .library(name: "vuTelemetrySDWebImage", targets: ["vuTelemetrySDWebImage", "VUSDWebImageBootstrap", "vuTelemetrySDWebImageDeps", "vuTelemetry", "VuTelemetryBootstrap", "vuTelemetryDeps"]),
        .plugin(name: "VUInstrumentationPlugin", targets: ["VUInstrumentationPlugin"]),
        .plugin(name: "VUInstrumentationCommand", targets: ["VUInstrumentationCommand"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", exact: "5.21.7"),
    ],
    targets: [
        .binaryTarget(name: "vuTelemetry", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.4/vuTelemetrySDWebImage.xcframework.zip", checksum: "150490bc9b9c97311371fad63f09e45d7751d8639dd13d1258d8199ead4d38a4"),
        .target(name: "VuTelemetryBootstrap", path: "Bootstrap/VuTelemetryBootstrap", publicHeadersPath: "."),
        .target(name: "vuTelemetryDeps", path: "Deps"),
        .binaryTarget(name: "vuTelemetrySDWebImage", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.4/vuTelemetrySDWebImage.xcframework.zip", checksum: "5a5e24d2401767d7fea2621a4e74b13831b88e24d6545936765b32e67aef9933"),
        .target(name: "VUSDWebImageBootstrap", path: "Bootstrap/VUSDWebImageBootstrap", publicHeadersPath: "include"),
        .target(name: "vuTelemetrySDWebImageDeps", dependencies: [
            .product(name: "SDWebImage", package: "SDWebImage"),
        ], path: "DepsSDWI"),
        .binaryTarget(name: "VUSourceInstrumenter", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.4/VUSourceInstrumenter.artifactbundle.zip", checksum: "90e6b703423191f12a61260de8621b7d922fd0325fe509a8df3be9fe457795ae"),
        .plugin(
            name: "VUInstrumentationPlugin",
            capability: .buildTool(),
            dependencies: ["VUSourceInstrumenter"],
            path: "Plugins/VUInstrumentationPlugin"
        ),
        .plugin(
            name: "VUInstrumentationCommand",
            capability: .command(
                intent: .custom(
                    verb: "vu-instrument",
                    description: "Install, verify, or uninstall vuTelemetry SwiftUI instrumentation phases"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Injects and manages Xcode build phases for SwiftUI instrumentation"
                    )
                ]
            ),
            dependencies: ["VUSourceInstrumenter"],
            path: "Plugins/VUInstrumentationCommand"
        ),
    ]
)
