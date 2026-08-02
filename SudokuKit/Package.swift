// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuKit",
    products: [
        .library(name: "SudokuKit", targets: ["SudokuKit"])
    ],
    targets: [
        .target(name: "SudokuKit"),
        .testTarget(name: "SudokuKitTests", dependencies: ["SudokuKit"]),
    ]
)
