import KanbananaCore
import KanbananaServices
import AppKit
import SwiftUI

@main struct RenderPreview {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agent-kanban-render-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = UserDefaults(suiteName: root.lastPathComponent)!
        defer { preferences.removePersistentDomain(forName: root.lastPathComponent) }
        if let layout = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_LAYOUT"] { preferences.set(layout, forKey: "boardLayout") }
        if let background = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_BACKGROUND"] { preferences.set(background, forKey: BoardBackground.preferenceKey) }
        if let cards = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_CARDS"] { preferences.set(cards, forKey: CardPaper.preferenceKey) }
        if let theme = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_THEME"] { preferences.set(theme, forKey: BoardTheme.preferenceKey) }
        let mode = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_MODE"] ?? "board"
        let state = DemoData.state(mode: mode, priority: ProcessInfo.processInfo.environment["KANBAN_PREVIEW_PRIORITY"] == "1")
        let store = await BoardStore.loaded(root: root, start: false, initialState: state, credentials: DemoCredentials())
        DemoData.showHealth(in: store)
        store.parking = mode == "parking"
        let boats = state.projects[1]
        if CommandLine.arguments.count > 2 { store.search = CommandLine.arguments[2] }
        if let photoID = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_PHOTO"], let index = PhotoBackdrop.photos.firstIndex(where: { $0.id == photoID }) {
            preferences.set(PhotoBackdrop.offset(selecting: index, at: .now, context: "Math interactives Weekend atlas Writing"), forKey: "photoOffset")
        }
        let content: AnyView
        switch mode {
        case "photolibrary": content = AnyView(PhotoLibraryView(photoOffset: .constant(0), context: ""))
        case "photocrops":
            content = AnyView(VStack(alignment: .leading, spacing: 12) {
                Text("kanbanana / eighteen little worlds").font(.system(size: 24, weight: .medium, design: .serif))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(PhotoBackdrop.photos) { photo in
                        VStack(alignment: .leading, spacing: 5) {
                            CroppedPhotograph(photo: photo, thumbnail: true).frame(height: 300)
                            Text(photo.title).font(.system(size: 10)).lineLimit(1)
                        }
                    }
                }
            }.padding(20).foregroundStyle(.white).background(Color.black))
        case "icons": content = AnyView(ProjectIconLibrary(store: store, project: boats, done: {}).padding(24).background(BoardStyle.canvas))
        case "projects": content = AnyView(ProjectsView(store: store))
        case "stacks": content = AnyView(BoardView(store: store, initiallyStacked: true, layoutPreferences: preferences))
        case "focus":
            preferences.set(BoardLayout.focus.rawValue, forKey: "boardLayout")
            content = AnyView(BoardView(store: store, layoutPreferences: preferences))
        case "lanes", "outage":
            preferences.set(BoardLayout.projects.rawValue, forKey: "boardLayout")
            content = AnyView(BoardView(store: store, layoutPreferences: preferences))
        default: content = AnyView(BoardView(store: store, layoutPreferences: preferences))
        }
        let view = content.environment(\.photoResourceRoot, resources).environment(\.colorScheme, BoardAppearance.saved(in: preferences).scheme).environment(\.boardAppearance, BoardAppearance.saved(in: preferences))
        let host = NSHostingView(rootView: view)
        let boardMode = ["board", "stacks", "lanes", "outage", "parking"].contains(mode)
        let width = Double(ProcessInfo.processInfo.environment["KANBAN_PREVIEW_WIDTH"] ?? (mode == "focus" ? "300" : boardMode ? "840" : "500")) ?? 840
        host.frame = NSRect(x: 0, y: 0, width: width, height: mode == "photocrops" ? 1040 : mode == "photolibrary" ? 570 : mode == "focus" ? 740 : boardMode ? 574 : 450)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        let target = URL(fileURLWithPath: CommandLine.arguments[1])
        try rep.representation(using: .png, properties: [:])?.write(to: target)
        await store.stop()
        print("Available icons: \(ProjectSymbol.availableIndices.count)/\(ProjectSymbol.palette.count). Colors: \(ProjectColor.palette.count).")
        for index in ProjectSymbol.palette.indices where !ProjectSymbol.availableIndices.contains(index) { print("Unavailable symbol: \(ProjectSymbol.palette[index].systemName)") }
    }
}
