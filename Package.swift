// swift-tools-version:5.9
import PackageDescription

// The GitHub organization of the suite's repositories: the one name to change should it be renamed (the
// suite repository's scripts/rename-organization.sh does it in every repository).
let organization = "love-suite"

// The file layer of the suite's file apps (Explorer, Desktop, Bar, Viewer, Suite Settings): what a file is,
// what a folder holds, the rules of each operation, the Trash, and the file views. Only the apps that
// handle files depend on it; the others never see it.
let suiteCore = Target.Dependency.product(name: "SuiteCore", package: "suite-core")

let package = Package(
    name: "SuiteFiles",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SuiteFilesCore", targets: ["SuiteFilesCore"]),
        .library(name: "SuiteFilesUI", targets: ["SuiteFilesUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/\(organization)/suite-core", .upToNextMinor(from: "27.1.0-dev.1")),
    ],
    targets: [
        // What a file is, what a folder holds, the rules of each operation, the Trash. No UI, unit-tested.
        .target(
            name: "SuiteFilesCore",
            dependencies: [suiteCore],
            linkerSettings: [.linkedFramework("CoreServices")]
        ),
        .testTarget(name: "SuiteFilesCoreTests", dependencies: ["SuiteFilesCore", suiteCore]),

        // The file views and actions the desktop, the windows and Bar share, each with macOS's look by
        // default and its variants as settings.
        .target(
            name: "SuiteFilesUI",
            dependencies: ["SuiteFilesCore", suiteCore],
            resources: [.process("Resources")],
            linkerSettings: [.linkedFramework("Quartz")]
        ),
        .testTarget(name: "SuiteFilesUITests", dependencies: ["SuiteFilesUI"]),
    ]
)
