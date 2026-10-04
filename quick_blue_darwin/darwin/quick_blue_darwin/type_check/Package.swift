// swift-tools-version: 5.9
// Linux-only harness that type-checks the Darwin BLE plugin sources without a
// macOS SDK. Every Apple framework the plugin imports is replaced by a
// signature-faithful stub target whose module name matches the import.
import PackageDescription

let package = Package(
    name: "quick_blue_darwin_type_check",
    products: [
        .library(name: "QuickBlueDarwinPluginTypeCheck", targets: ["QuickBlueDarwinPluginTypeCheck"]),
    ],
    targets: [
        .target(name: "CoreBluetooth", path: "Sources/CoreBluetooth"),
        .target(name: "Flutter", path: "Sources/Flutter"),
        .target(name: "FlutterMacOS", path: "Sources/FlutterMacOS"),
        .target(name: "UIKit", path: "Sources/UIKit"),
        .target(
            name: "AccessorySetupKit",
            dependencies: ["CoreBluetooth", "UIKit"],
            path: "Sources/AccessorySetupKit"
        ),
        .target(name: "QuickBlueConnectionOwnership", path: "Sources/QuickBlueConnectionOwnership"),
        .target(name: "QuickBlueRestorationSummary", path: "Sources/QuickBlueRestorationSummary"),
        .target(
            name: "QuickBlueDarwinPluginTypeCheck",
            dependencies: [
                "CoreBluetooth",
                "Flutter",
                "UIKit",
                "AccessorySetupKit",
                "QuickBlueConnectionOwnership",
                "QuickBlueRestorationSummary",
            ],
            path: "Sources/QuickBlueDarwinPluginTypeCheck",
            swiftSettings: [.define("QUICK_BLUE_TYPE_CHECK_DARWIN")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
