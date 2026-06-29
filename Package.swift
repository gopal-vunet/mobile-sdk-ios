// swift-tools-version: 6.1
// vuTelemetry v0.0.5 — pre-built binary package. See README.md.
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
        .binaryTarget(name: "vuTelemetry", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.5/vuTelemetry.xcframework.zip", checksum: "44f9abbbc3f89cd301fb08295505e25845a73687816b72c1aa4a3327da1fac63"),
        .target(name: "VuTelemetryBootstrap", path: "Bootstrap/VuTelemetryBootstrap", publicHeadersPath: "."),
        .target(name: "vuTelemetryDeps", path: "Deps"),
        .binaryTarget(name: "vuTelemetrySDWebImage", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.5/vuTelemetrySDWebImage.xcframework.zip", checksum: "c71ae32299cc6b4538252f912514c24406c6143a141bab4396c983cf05bab321"),
        .target(name: "VUSDWebImageBootstrap", path: "Bootstrap/VUSDWebImageBootstrap", publicHeadersPath: "include"),
        .target(name: "vuTelemetrySDWebImageDeps", dependencies: [
            .product(name: "SDWebImage", package: "SDWebImage"),
        ], path: "DepsSDWI"),
        .binaryTarget(name: "VUSourceInstrumenter", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.5/VUSourceInstrumenter.artifactbundle.zip", checksum: "8989499f4c29f27ea1b1c585a00c2d8346cd7d414469884c61c1a2d1000c8325"),
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
