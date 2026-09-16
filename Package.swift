// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AgentKanban",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AgentKanban", targets: ["AgentKanban"])],
    targets: [
        .executableTarget(name: "AgentKanban", path: "Sources/AgentKanban"),
        .testTarget(name: "AgentKanbanTests", dependencies: ["AgentKanban"], path: "tests/AgentKanbanTests")
    ],
    swiftLanguageModes: [.v5]
)
