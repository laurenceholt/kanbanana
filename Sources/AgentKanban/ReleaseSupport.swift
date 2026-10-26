import KanbananaCore
import AppKit
import SwiftUI

@MainActor enum BrandArtwork {
    static let image: NSImage? = {
        let urls = [Bundle.main.resourceURL?.appendingPathComponent("Branding/banana.png"),
                    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/Branding/banana.png")]
        return urls.compactMap { $0 }.compactMap { NSImage(contentsOf: $0) }.first
    }()
}
struct BananaMark: View {
    var body: some View {
        if let image = BrandArtwork.image { Image(nsImage: image).resizable().scaledToFit().accessibilityHidden(true) }
    }
}

enum IntegrationInfo {
    static var versions: [String: String] {
        var result = [String: String]()
        for (name, id) in [("claude", "com.anthropic.claudefordesktop"), ("codex", "com.openai.codex")] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), let bundle = Bundle(url: url) {
                result[name] = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown version"
            } else { result[name] = "Not installed" }
        }
        return result
    }

}

struct WelcomeView: View {
    @ObservedObject var store: BoardStore
    @Environment(\.boardAppearance) private var appearance
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { BananaMark().frame(width: 36, height: 36); Text("Welcome to kanbanana").font(.title2.bold()) }
            Text("A small window for the Claude Code and Codex conversations stored on this Mac.")
            ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("Which apps do you use here?").font(.headline)
            ForEach(["claude", "codex"], id: \.self) { provider in
                Toggle(isOn: Binding(get: { !store.privacy.disabledProviders.contains(provider) }, set: { store.setProvider(provider, enabled: $0) })) {
                    Text("\(provider == "claude" ? "Claude Desktop Code" : "Codex Desktop") · \(IntegrationInfo.versions[provider] ?? "Not installed")")
                }
            }
            Text("We look for local conversations active in the last two weeks, including finished ones. If this Mac has no supported history yet, your board will start empty.").font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Do your agents work on another Mac?").font(.headline)
            Text("Run kanbanana on that Mac. Boards do not sync between Macs, and cloud-only conversations cannot be read here.").font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("No API key needed to get started").font(.headline)
            Text("Cards show local excerpts by default. Later, you can enable optional paid OpenAI summaries in Settings. A key is not needed to discover conversations.").font(.callout).fixedSize(horizontal: false, vertical: true)
            Link("Read the privacy details", destination: URL(string: "https://github.com/laurenceholt/kanbanana/blob/main/PRIVACY.md")!)
            Link("Getting started on this Mac", destination: HelpLinks.topic("your-first-conversation"))
            } }
            Button("Look for conversations") { store.completeOnboarding() }.buttonStyle(.borderedProminent)
        }.padding(24).frame(width: 470, height: 540).background(appearance.canvas).foregroundStyle(appearance.ink)
    }
}

struct IntegrationOptions: View {
    @ObservedObject var store: BoardStore
    @State private var codexHome = ""
    @State private var claudeHome = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(["claude", "codex"], id: \.self) { provider in
                Toggle("Monitor \(provider == "claude" ? "Claude Code" : "Codex") (\(IntegrationInfo.versions[provider] ?? "Unknown"))", isOn: Binding(get: { !store.privacy.disabledProviders.contains(provider) }, set: { store.setProvider(provider, enabled: $0) }))
            }
            DisclosureGroup("Custom session locations") {
                HStack { TextField("Codex home (default ~/.codex)", text: $codexHome); Button("Apply") { store.setSourceHome("codex", path: codexHome) } }
                HStack { TextField("Claude home (default ~/.claude)", text: $claudeHome); Button("Apply") { store.setSourceHome("claude", path: claudeHome) } }
                Text("Set these only if you use a custom CODEX_HOME or CLAUDE_CONFIG_DIR. Claude Desktop metadata still comes from its standard Application Support folder.").font(.caption)
            }
        }.onAppear { codexHome = store.privacy.codexHome ?? ""; claudeHome = store.privacy.claudeHome ?? "" }
    }
}

struct DataControls: View {
    @ObservedObject var store: BoardStore
    @State private var restoreURL: URL?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Your data").font(.headline)
            Text("Seven rolling local backups, at most one per hour plus a backup before restoration. Exports contain requests and notes; diagnostic reports do not.").font(.caption)
            HStack {
                Button("Export board…") {
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "kanbanana-board.json"; panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url { Task { await store.exportBoard(to: url) } }
                }
                Button("Restore…") {
                    let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK { restoreURL = panel.url }
                }
                Button("Diagnostics…") {
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "kanbanana-diagnostics.json"; panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url { Task { await store.exportDiagnostics(to: url) } }
                }
            }
            HStack {
                Button("Open data folder") { NSWorkspace.shared.open(store.root) }
                Button("Open backups") { NSWorkspace.shared.open(store.root.appendingPathComponent("Backups")) }
            }
            if let text = store.dataStatus { Text(text).font(.caption).textSelection(.enabled) }
        }.confirmationDialog("Replace this board with the selected export? Your current board will be backed up first. Cloud summaries will be switched off.", isPresented: Binding(get: { restoreURL != nil }, set: { if !$0 { restoreURL = nil } }), titleVisibility: .visible) {
            Button("Restore board", role: .destructive) { if let url = restoreURL { Task { await store.restoreBoard(from: url) } }; restoreURL = nil }
            Button("Cancel", role: .cancel) { restoreURL = nil }
        }
    }
}
