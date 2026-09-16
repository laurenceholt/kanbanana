import KanbananaCore
import AppKit
import SwiftUI

@main struct AgentKanbanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var boardWindow: BoardWindow!
    private var layout = BoardLayout(rawValue: UserDefaults.standard.string(forKey: "boardLayout") ?? "") ?? .columns
    private var changingLayout = false
    private var frameName: String { layout.frameName }
    private var store: BoardStore!
    private var demoRoot: URL?
    private var preferences = UserDefaults.standard
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--demo") {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("kanbanana-demo-" + UUID().uuidString)
            demoRoot = root
            preferences = UserDefaults(suiteName: root.lastPathComponent)!
            preferences.set(BoardLayout.focus.rawValue, forKey: "boardLayout")
            layout = .focus
            store = BoardStore(root: root, start: false, initialState: DemoData.state(), credentials: DemoCredentials(),
                               summarize: { _, _, _ in throw DemoCredentials.Disabled() })
        } else { store = BoardStore() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        boardWindow = BoardWindow(contentRect: NSRect(origin: .zero, size: layout.defaultSize), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        boardWindow.title = demoRoot == nil ? "kanbanana" : "kanbanana · demo"
        boardWindow.titleVisibility = demoRoot == nil ? .hidden : .visible
        boardWindow.titlebarAppearsTransparent = true
        boardWindow.backgroundColor = NSColor(BoardAppearance.saved(in: preferences).canvas)
        boardWindow.appearance = NSAppearance(named: BoardAppearance.saved(in: preferences).isDark ? .darkAqua : .aqua)
        boardWindow.isReleasedWhenClosed = false
        boardWindow.contentMinSize = layout.minimumSize
        let resources = Bundle.main.resourceURL?.appendingPathComponent("Photos")
        let resourceRoot = resources.map { FileManager.default.fileExists(atPath: $0.path) } == true
            ? Bundle.main.resourceURL : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
        let host = NSHostingView(rootView: BoardView(store: store, layoutPreferences: preferences, layoutChanged: { [weak self] in self?.changeLayout($0) }, appearanceChanged: { [weak self] in self?.boardWindow.backgroundColor = NSColor($0.canvas); self?.boardWindow.appearance = NSAppearance(named: $0.isDark ? .darkAqua : .aqua) }).environment(\.photoResourceRoot, resourceRoot))
        host.sizingOptions = []
        boardWindow.contentView = host
        if demoRoot != nil || !boardWindow.setFrameUsingName(frameName) { boardWindow.center() }
        fitOnScreen()
        if demoRoot == nil { boardWindow.setFrameAutosaveName(frameName) }
        boardWindow.delegate = self
        store.onChange = { [weak self] in self?.updateStatus() }
        updateStatus()
        if demoRoot != nil { Task { await store.ready(); DemoData.showHealth(in: store) } }
        DispatchQueue.main.async { [weak self] in self?.showPanel() }
    }
    private func changeLayout(_ next: BoardLayout) {
        guard next.frameName != frameName else { layout = next; return }
        CardDragSession.cancel()
        changingLayout = true
        let previous = boardWindow.frame
        if demoRoot == nil { boardWindow.saveFrame(usingName: frameName) }
        boardWindow.setFrameAutosaveName("")
        layout = next
        boardWindow.contentMinSize = next.minimumSize
        if demoRoot != nil || !boardWindow.setFrameUsingName(frameName), let screen = boardWindow.screen ?? NSScreen.main {
            boardWindow.setFrame(next.initialFrame(beside: previous, on: screen.visibleFrame), display: true)
        }
        fitOnScreen()
        if demoRoot == nil { boardWindow.setFrameAutosaveName(frameName) }
        changingLayout = false
        saveFrame()
    }
    private func fitOnScreen() {
        guard let screen = boardWindow.screen ?? NSScreen.main else { return }
        boardWindow.setFrame(layout.fitting(boardWindow.frame, on: screen.visibleFrame), display: true)
    }
    private func saveFrame() {
        guard !changingLayout, demoRoot == nil else { return }
        boardWindow.saveFrame(usingName: frameName)
    }
    private func updateStatus() {
        let unknown = store.count(.unknown)
        let title = NSMutableAttributedString()
        for col in Column.board + (unknown > 0 ? [.unknown] : []) {
            if title.length > 0 { title.append(NSAttributedString(string: "\u{2009}")) }
            if let image = NSImage(systemSymbolName: col.symbol, accessibilityDescription: col.title)?.withSymbolConfiguration(.init(pointSize: 10, weight: .regular)) {
                image.isTemplate = true
                let attachment = NSTextAttachment(); attachment.image = image; attachment.bounds = NSRect(x: 0, y: -2, width: 10, height: 10)
                title.append(NSAttributedString(attachment: attachment))
            }
            title.append(NSAttributedString(string: "\u{200A}\(store.count(col))"))
        }
        title.addAttribute(.font, value: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium), range: NSRange(location: 0, length: title.length))
        if let banana = BrandArtwork.image?.copy() as? NSImage {
            banana.size = NSSize(width: 16, height: 16)
            statusItem.button?.image = banana
            statusItem.button?.imagePosition = .imageLeading
        }
        statusItem.button?.attributedTitle = title
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        statusItem.button?.toolTip = "kanbanana — " + Column.board.map { "\($0.title): \(store.count($0))" }.joined(separator: ", ") + (unknown > 0 ? "; \(unknown) unavailable" : "")
    }
    @objc private func toggle() {
        if boardWindow.isVisible && boardWindow.isKeyWindow { boardWindow.performClose(nil) }
        else { showPanel() }
    }
    private func showPanel() {
        NSApp.activate(ignoringOtherApps: true)
        if boardWindow.isMiniaturized { boardWindow.deminiaturize(nil) }
        boardWindow.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(); return false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { [weak self] in
            await self?.store?.stop()
            if let root = self?.demoRoot {
                try? FileManager.default.removeItem(at: root)
                self?.preferences.removePersistentDomain(forName: root.lastPathComponent)
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if demoRoot == nil { sender.saveFrame(usingName: frameName) }
        sender.orderOut(nil)
        return false
    }
    func windowDidResize(_ notification: Notification) { saveFrame() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
