// swift-tools-version: 5.9
// vuTelemetry v0.0.1 — pre-built binary package. See README.md.
// Built WITH library evolution: portable .swiftinterface, consumable by any Xcode >= Xcode 26.5.
import PackageDescription

let package = Package(
    name: "vuTelemetry",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "vuTelemetry", targets: ["vuTelemetry", "VuTelemetryBootstrap", "vuTelemetryDeps"]),
        .library(name: "vuTelemetrySDWebImage", targets: ["vuTelemetrySDWebImage", "VUSDWebImageBootstrap", "vuTelemetrySDWebImageDeps", "vuTelemetry", "VuTelemetryBootstrap", "vuTelemetryDeps"]),
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/PLCrashReporter", exact: "1.12.2"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", exact: "2.3.0"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", exact: "2.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.9.1"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", exact: "5.21.7"),
    ],
    targets: [
        .binaryTarget(name: "vuTelemetry", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.1/vuTelemetry.xcframework.zip", checksum: "bf5063bdbe3a512998b88784146eac51798efacc0aa0b258f0335dff1e4491c8"),
        .target(name: "VuTelemetryBootstrap", path: "Bootstrap/VuTelemetryBootstrap", publicHeadersPath: "."),
        .target(name: "vuTelemetryDeps", dependencies: [
            .product(name: "CrashReporter", package: "PLCrashReporter"),
            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
            .product(name: "Sessions", package: "opentelemetry-swift"),
            .product(name: "SignPostIntegration", package: "opentelemetry-swift"),
            .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
            .product(name: "PersistenceExporter", package: "opentelemetry-swift"),
        ], path: "Deps"),
        .binaryTarget(name: "vuTelemetrySDWebImage", url: "https://github.com/gopal-vunet/mobile-sdk-ios/releases/download/v0.0.1/vuTelemetrySDWebImage.xcframework.zip", checksum: "46780e398ab48e6fa2786d9191c0c3da7a9cec0e9d2dc1b73d07698ec5140823"),
        .target(name: "VUSDWebImageBootstrap", path: "Bootstrap/VUSDWebImageBootstrap", publicHeadersPath: "include"),
        .target(name: "vuTelemetrySDWebImageDeps", dependencies: [
            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
            .product(name: "SDWebImage", package: "SDWebImage"),
        ], path: "DepsSDWI"),
    ]
)
