// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnKeyBoard",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EnKeyBoard", targets: ["EnKeyBoard"]),
        .executable(name: "enkeyboard-cli", targets: ["EnKeyBoardCLI"]),
        .executable(name: "enkeyboard-checks", targets: ["EnKeyBoardChecks"]),
        .executable(name: "enkeyboard-source", targets: ["EnKeyBoardSourceTool"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "InputSourceSupport", linkerSettings: [.linkedFramework("Carbon")]),
        .target(name: "EnKeyBoardCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "EnKeyBoard", dependencies: ["EnKeyBoardCore", "InputSourceSupport"],
                          linkerSettings: [.linkedFramework("InputMethodKit"), .linkedFramework("Carbon")]),
        .executableTarget(name: "EnKeyBoardCLI", dependencies: ["EnKeyBoardCore"]),
        .executableTarget(name: "EnKeyBoardChecks", dependencies: ["EnKeyBoardCore"], path: "Tests/EnKeyBoardCoreTests"),
        .executableTarget(name: "EnKeyBoardSourceTool", dependencies: ["InputSourceSupport"])
    ],
    swiftLanguageModes: [.v5]
)
