// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AgentKanban",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AgentKanban", targets: ["AgentKanban"])],
    targets: [
        .target(name: "KanbananaCore"),
        .target(name: "KanbananaServices", dependencies: ["KanbananaCore"]),
        .executableTarget(name: "AgentKanban", dependencies: ["KanbananaCore", "KanbananaServices"], path: "Sources/AgentKanban"),
        .testTarget(name: "AgentKanbanTests", dependencies: ["AgentKanban", "KanbananaCore", "KanbananaServices"], path: "tests/AgentKanbanTests"),
        .testTarget(name: "KanbananaCoreTests", dependencies: ["KanbananaCore"], path: "tests/KanbananaCoreTests"),
        .testTarget(name: "KanbananaServicesTests", dependencies: ["KanbananaCore", "KanbananaServices"], path: "tests/KanbananaServicesTests", resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v6]
)
