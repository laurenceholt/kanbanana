import AppKit
import SwiftUI

@main struct RenderPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        PhotoBackdrop.resourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agent-kanban-render-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = UserDefaults(suiteName: root.lastPathComponent)!
        defer { preferences.removePersistentDomain(forName: root.lastPathComponent) }
        if let layout = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_LAYOUT"] { preferences.set(layout, forKey: "boardLayout") }
        if let background = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_BACKGROUND"] { preferences.set(background, forKey: BoardBackground.preferenceKey) }
        if let cards = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_CARDS"] { preferences.set(cards, forKey: CardPaper.preferenceKey) }
        if let theme = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_THEME"] { preferences.set(theme, forKey: BoardTheme.preferenceKey) }
        let store = BoardStore(root: root, start: false)
        store.needsOnboarding = false
        store.scanning = false
        store.health = ["claude": "Connected", "codex": "Connected"]
        store.updatedAt = Date()
        let math = Project(name: "Math interactives", note: "Build a set of fraction models.", colorIndex: 0, symbolIndex: 0)
        let boats = Project(name: "Weekend atlas", colorIndex: 1, symbolIndex: 6)
        let writing = Project(name: "Writing", colorIndex: 0, symbolIndex: 1)
        store.saved.projects = [math, boats, writing]
        let mode = ProcessInfo.processInfo.environment["KANBAN_PREVIEW_MODE"] ?? "board"
        var samples: [(String, String, String, Column, String)] = [
            ("Build fraction model", "claude", "Apply the new framework to the fractions interactive.", .running, math.id),
            ("Plan a weekend route", "codex", "Collect marina and appointment details for the shortlist.", .running, boats.id),
            ("Fix dragging", "codex", "Fix the drag target labels and check touch behavior.", .needsMe, math.id),
            ("Compare shortlisted boats", "claude", "Collect ferry routes and walking trail details.", .ready, boats.id),
            ("Update evaluations", "claude", "Apply the revised rubric to the latest interactive.", .dealtWith, math.id),
            ("Polish article", "codex", "Revise the opening and simplify the final paragraph.", .ready, writing.id),
            ("Confirm marina map", "codex", "Check the stand numbers for our appointments.", .dealtWith, boats.id),
            ("Package the demo", "codex", "Build the installer for the interactive builder.", .todo, math.id),
            ("Plan boat visits", "claude", "Prepare a shortlist of boats to visit.", .todo, boats.id)
        ]
        if ["stacks", "focus"].contains(mode) {
            samples += [
                ("Test fractions on touch screens", "codex", "Check pointer and touch interactions.", .running, math.id),
                ("Review the builder installer", "codex", "Try the installer on a clean Mac.", .ready, math.id),
                ("Apply accessibility updates", "claude", "Apply the latest keyboard navigation rules.", .ready, math.id),
                ("Review the new rubric", "codex", "Review the evaluations and suggest missing cases.", .ready, math.id),
                ("Check Weekend atlas appointments", "codex", "Verify the appointment times with the shortlist.", .ready, boats.id),
                ("Finish fraction examples", "codex", "Check the final example values.", .dealtWith, math.id)
            ]
        }
        if mode == "parking" {
            let originals = samples
            samples += (1...4).flatMap { round in
                originals.map { ("\($0.0) · round \(round)", $0.1, $0.2, $0.3, $0.4) }
            }
            store.parking = true
        }
        for (index, s) in samples.enumerated() {
            let now = Date().timeIntervalSince1970 - Double(index * 400)
            let r = RequestItem(id: "request-\(index)", text: s.2, time: now)
            let card = Conversation(id: "demo-\(index)", provider: s.1, nativeID: "demo", title: s.0, folder: "", updated: now, requests: [r], state: s.3 == .dealtWith || s.3 == .todo ? .ready : s.3, reason: s.3 == .needsMe ? "Permission needed" : "", response: "", eventID: "event", eventTime: now, url: "")
            store.saved.cards.append(card)
            var d = Disposition(); d.projectID = s.4
            if mode == "parking" { d.parked = true }
            if ProcessInfo.processInfo.environment["KANBAN_PREVIEW_PRIORITY"] == "1", [1, 2, 5, 6, 7, 10].contains(index) { d.priority = true }
            if s.3 == .dealtWith { d.acknowledgedRevision = card.revision }
            if s.3 == .todo {
                d.manualColumn = .todo; d.manualRevision = card.revision; d.todoRequestID = r.id
                if s.4 == math.id { d.todoNote = "Try the installer on a writer’s Mac." }
            }
            store.saved.dispositions[card.id] = d
            store.saved.summaries[card.id + ":" + r.id] = Summary(text: r.text, inputHash: BoardStore.hash(r.text))
        }
        if CommandLine.arguments.count > 2 { store.search = CommandLine.arguments[2] }
        if mode == "outage" {
            store.health["codex"] = "Unavailable · History database busy"
            for i in store.saved.cards.indices where store.saved.cards[i].provider == "codex" {
                store.saved.cards[i].observationIssue = "History database busy"
            }
        }
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
        let view = content.environment(\.colorScheme, BoardAppearance.saved(in: preferences).scheme).environment(\.boardAppearance, BoardAppearance.saved(in: preferences))
        let host = NSHostingView(rootView: view)
        let boardMode = ["board", "stacks", "lanes", "outage", "parking"].contains(mode)
        let width = Double(ProcessInfo.processInfo.environment["KANBAN_PREVIEW_WIDTH"] ?? (mode == "focus" ? "300" : boardMode ? "840" : "500")) ?? 840
        host.frame = NSRect(x: 0, y: 0, width: width, height: mode == "photocrops" ? 1040 : mode == "photolibrary" ? 570 : mode == "focus" ? 740 : boardMode ? 574 : 450)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        let target = URL(fileURLWithPath: CommandLine.arguments[1])
        try rep.representation(using: .png, properties: [:])?.write(to: target)
        print("Available icons: \(ProjectSymbol.availableIndices.count)/\(ProjectSymbol.palette.count). Colors: \(ProjectColor.palette.count).")
        for index in ProjectSymbol.palette.indices where !ProjectSymbol.availableIndices.contains(index) { print("Unavailable symbol: \(ProjectSymbol.palette[index].systemName)") }
    }
}
