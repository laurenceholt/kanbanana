import AppKit
import SwiftUI
import KanbananaCore
import KanbananaServices

/// Renders real app components with explicitly synthetic state; never captures the desktop.
@main struct RenderDemo {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("kanbanana-film-" + UUID().uuidString)
        let preferences = UserDefaults(suiteName: root.lastPathComponent)!
        defer {
            preferences.removePersistentDomain(forName: root.lastPathComponent)
            try? FileManager.default.removeItem(at: root)
        }
        let state = DemoData.state(mode: "focus", priority: false)
        let store = await BoardStore.loaded(root: root, start: false, initialState: state,
            credentials: DemoCredentials(), summarize: { _, _, _ in throw DemoCredentials.Disabled() })
        DemoData.showHealth(in: store)
        let context = state.projects.map(\.name).joined(separator: " ")
        let art = ArtBackdrop.artworks.firstIndex { $0.id == "searching-void" }!
        preferences.set(ArtBackdrop.offset(selecting: art, at: .now, context: context), forKey: "photoOffset")
        preferences.set(BoardBackground.butter.rawValue, forKey: BoardBackground.preferenceKey)
        preferences.set(CardPaper.cream.rawValue, forKey: CardPaper.preferenceKey)
        var manifest = [[String: Any]]()
        func appearance(_ theme: BoardTheme) -> BoardAppearance {
            preferences.set(theme.rawValue, forKey: BoardTheme.preferenceKey)
            return BoardAppearance(background: .butter, cards: .cream, theme: theme)
        }
        func board(_ layout: BoardLayout, _ style: BoardAppearance, width: CGFloat, height: CGFloat) -> AnyView {
            preferences.set(layout.rawValue, forKey: "boardLayout")
            return AnyView(BoardView(store: store, layoutPreferences: preferences)
                .frame(width: width, height: height)
                .environment(\.boardAppearance, style).environment(\.colorScheme, style.scheme)
                .environment(\.artResourceRoot, resources))
        }
        func render(_ id: String, duration: Double, title: String, detail: String, wide: Bool = false,
                    dark: Bool = false, content: AnyView) async throws {
            let view = DemoScene(title: title, detail: detail, wide: wide, dark: dark, content: content)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 1280, height: 720)
            host.layoutSubtreeIfNeeded()
            // Allow tasks and preference propagation to settle without reading any real service.
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw FilmError.render }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { throw FilmError.render }
            try data.write(to: output.appendingPathComponent(id + ".png"))
            manifest.append(["id": id, "duration": duration, "caption": title.replacingOccurrences(of: "\n", with: " ") + " " + detail])
            print("Rendered \(id)")
        }
        var style = appearance(.classic)
        try await render("01-focus", duration: 3, title: "Your agents.\nOne small\nwindow.",
            detail: "Keep up with Claude Code and Codex\nwithout another full-screen app.",
            content: board(.focus, style, width: 340, height: 584))
        style = appearance(.art)
        try await render("02-reports", duration: 4, title: "Know what\ncame back.",
            detail: "Ready to check shows a short report.\nRequest history keeps the trail.",
            content: board(.focus, style, width: 340, height: 584))
        try await render("03-priority-before", duration: 1, title: "Keep priorities\nat the top.",
            detail: "Star the release notes.\nThey move to the front of the list.",
            content: board(.focus, style, width: 340, height: 584))
        let notes = store.cards.first { $0.title == "Polish release notes" }!
        store.togglePriority(notes.id)
        assert(store.focusCards(in: .ready).first?.id == notes.id)
        try await render("04-priority-after", duration: 3, title: "Keep priorities\nat the top.",
            detail: "Star the release notes.\nThey move to the front of the list.",
            content: board(.focus, style, width: 340, height: 584))
        store.mark(notes, .dealtWith)
        assert(store.column(notes) == .dealtWith && !store.focusCards(in: .ready).contains { $0.id == notes.id })
        try await render("05-dealt-with", duration: 3, title: "Checked it?\nClear the card.",
            detail: "One click moves this round to Dealt with.\nA new request brings it back.",
            content: board(.focus, style, width: 340, height: 584))
        style = appearance(.classic)
        try await render("06-projects", duration: 5, title: "One project at a time.",
            detail: "Separate conversations. Shared projects. Across both apps.", wide: true,
            content: board(.projects, style, width: 1136, height: 460))
        let weather = state.projects[0]
        store.selectProject(weather.id)
        try await render("07-project-goal", duration: 4, title: "Keep the goal in view.",
            detail: "A project note reminds you what this work is for.", wide: true,
            content: board(.projects, style, width: 1136, height: 460))
        style = appearance(.night)
        try await render("08-history", duration: 4, title: "Remember\nwhat you asked.",
            detail: "One entry per request.\nYour chain of thought, easy to find.", dark: true,
            content: AnyView(HistoryView(store: store, cardID: notes.id)
                .environment(\.boardAppearance, style).environment(\.colorScheme, style.scheme)))
        style = appearance(.classic)
        let todo = store.cards.first { $0.title == "Package the preview" }!
        try await render("09-todo", duration: 4, title: "Leave the\nnext round\na note.",
            detail: "A To do reminder stays with the card\nuntil you’re ready to pick it up.",
            content: AnyView(TodoNoteView(store: store, card: todo)
                .environment(\.boardAppearance, style).environment(\.colorScheme, style.scheme)))
        store.selectProject(nil)
        style = appearance(.art)
        try await render("10-outro", duration: 4, title: "Less switching.\nMore making.",
            detail: "macOS · open source · local board\ngithub.com/laurenceholt/kanbanana", dark: true,
            content: board(.focus, style, width: 340, height: 584))
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("scenes.json"))
        await store.stop()
    }
    enum FilmError: Error { case render }
}

private struct DemoScene: View {
    let title: String
    let detail: String
    let wide: Bool
    let dark: Bool
    let content: AnyView
    private var ink: Color { dark ? Color(hex: 0xF7F1DD) : Color(hex: 0x202C2C) }
    var body: some View {
        ZStack {
            (dark ? Color(hex: 0x151D20) : Color(hex: 0xF4EDD9)).ignoresSafeArea()
            // Quiet editorial treatment: a yellow edge and generous type, real app UI.
            Rectangle().fill(Color(hex: 0xF2D13D)).frame(width: 10).frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    BananaMark().frame(width: 25, height: 25)
                    Text("kanbanana").font(BoardStyle.font(19, weight: .bold))
                    Spacer()
                    Text("macOS / fictional demo").font(.system(size: 12, weight: .medium, design: .monospaced)).opacity(0.6)
                }.padding(.bottom, wide ? 17 : 0)
                if wide {
                    Text(title).font(BoardStyle.font(42, weight: .bold)).tracking(-1.3)
                    Text(detail).font(BoardStyle.font(18)).opacity(0.7).padding(.top, 2).padding(.bottom, 16)
                    panel.frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                } else {
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 25) {
                            Text(title).font(BoardStyle.font(57, weight: .bold)).tracking(-1.8).fixedSize(horizontal: false, vertical: true)
                            Text(detail).font(BoardStyle.font(21)).lineSpacing(6).opacity(0.75).fixedSize(horizontal: false, vertical: true)
                        }.frame(width: 520, alignment: .leading)
                        Spacer(minLength: 0)
                        panel
                    }.frame(maxHeight: .infinity)
                }
                HStack {
                    Text("CLAUDE CODE + CODEX").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.8)
                    Spacer()
                    Text("Source beta · Download coming soon").font(BoardStyle.font(12)).opacity(0.6)
                }
            }.padding(.horizontal, 62).padding(.top, 28).padding(.bottom, 24)
        }.foregroundStyle(ink).frame(width: 1280, height: 720)
    }
    private var panel: some View {
        content.clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(dark ? 0.4 : 0.17), radius: 20, x: 0, y: 10)
    }
}
