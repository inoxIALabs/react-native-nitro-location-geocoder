// swift-tools-version: 6.0
import PackageDescription

// Development-only harness for the same request lifecycle and Core Location
// adapter that CocoaPods compiles. React Native/Nitro integration uses the podspec.
let package = Package(
    name: "LocationGeocoderNativeTests",
    platforms: [.macOS(.v12)],
    targets: [
        .target(
            name: "LocationGeocoderCore",
            path: "ios",
            exclude: ["Bridge.h", "HybridLocationGeocoder.swift"],
            sources: ["ReverseGeocodeRequest.swift", "SystemLocationGeocoder.swift"]
        ),
        .testTarget(
            name: "LocationGeocoderCoreTests",
            dependencies: ["LocationGeocoderCore"],
            path: "test/ios"
        ),
    ]
)
