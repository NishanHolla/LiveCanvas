// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LiveCanvas",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LiveCanvas", targets: ["LiveCanvas"])],
    targets: [.executableTarget(name: "LiveCanvas")]
)
