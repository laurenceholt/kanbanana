import KanbananaCore
import SwiftUI

enum HelpLinks {
    static let guide = URL(string: "https://github.com/laurenceholt/kanbanana/blob/main/docs/USER-GUIDE.md")!
    static func topic(_ anchor: String) -> URL { URL(string: guide.absoluteString + "#" + anchor)! }
    static let video = URL(string: "https://github.com/laurenceholt/kanbanana/blob/main/docs/media/kanbanana-demo.mp4")!
    static let apiKeys = URL(string: "https://platform.openai.com/api-keys")!
    static let billing = URL(string: "https://platform.openai.com/settings/organization/billing/overview")!
}

struct BoardHelpMenu: View {
    let openSettings: () -> Void
    var body: some View {
        Menu {
            Link("Getting started on this Mac", destination: HelpLinks.topic("your-first-conversation"))
            Link("How the board works", destination: HelpLinks.topic("using-the-board"))
            Link("Change your background", destination: HelpLinks.topic("appearance"))
            Button("Set up summaries…", action: openSettings)
            Link("API key setup guide", destination: HelpLinks.topic("optional-ai-summaries"))
            Divider()
            Link("Missing conversations and troubleshooting", destination: HelpLinks.topic("missing-conversations"))
            Link("Watch the one-minute overview", destination: HelpLinks.video)
            Button("Settings…", action: openSettings)
        } label: {
            Image(systemName: "questionmark.circle").font(.system(size: 13)).frame(width: 24, height: 24)
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Help — getting started, appearance and summaries").accessibilityLabel("Help")
    }
}

enum EmptyBoardState: Equatable {
    case scanning, monitoringOff, connectionProblem, noLocalConversations, filtered, parkingEmpty, allParked
    case columnEmpty(Column)

    var title: String {
        switch self {
        case .scanning: "Looking on this Mac…"
        case .monitoringOff: "Monitoring is off"
        case .connectionProblem: "Conversations couldn't be read"
        case .noLocalConversations: "No recent conversations found on this Mac"
        case .filtered: "No matching conversations"
        case .parkingEmpty: "Nothing parked here"
        case .allParked: "Your conversations are parked"
        case .columnEmpty(let column): "Nothing in \(column.title)"
        }
    }
    var message: String {
        switch self {
        case .scanning: "Checking locally stored Claude Code and Codex conversations. You don't need to start a new job if recent history is already here."
        case .monitoringOff: "Choose Claude Desktop Code or Codex Desktop in Settings to start finding local conversations."
        case .connectionProblem: "Check the source status below. This doesn't mean your board is up to date. Retry, or open Settings to check your integrations."
        case .noLocalConversations: "Start or continue a conversation in Claude Desktop's Code section or Codex Desktop on this Mac. Recent locally stored conversations can appear even when they have finished."
        case .filtered: "Clear the search and project filter to see the rest of your board."
        case .parkingEmpty: "Conversations you park will appear here, ready to restore."
        case .allParked: "Open the parking lot to find and restore them."
        case .columnEmpty: "Your conversations may be in another status. Use the counts above to switch."
        }
    }
}

extension BoardStore {
    func emptyBoardState(focusColumn: Column? = nil) -> EmptyBoardState {
        if focusColumn == nil && (selectedProject != nil || !search.isEmpty) { return .filtered }
        if focusColumn == nil && parking { return .parkingEmpty }
        if cards.isEmpty {
            if ProviderID.allCases.allSatisfy({ privacy.disabledProviders.contains($0.rawValue) }) { return .monitoringOff }
            if scanning { return .scanning }
            if !sourceWarnings.isEmpty || readerError != nil { return .connectionProblem }
            return .noLocalConversations
        }
        if parkedCount == cards.count { return .allParked }
        return focusColumn.map(EmptyBoardState.columnEmpty) ?? .filtered
    }
}

struct EmptyBoardView: View {
    @ObservedObject var store: BoardStore
    var focusColumn: Column? = nil
    let openSettings: () -> Void
    let openParking: () -> Void
    @Environment(\.boardAppearance) private var appearance
    private var state: EmptyBoardState { store.emptyBoardState(focusColumn: focusColumn) }
    private var explainsSources: Bool {
        [.scanning, .monitoringOff, .connectionProblem, .noLocalConversations].contains(state)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state == .scanning { ProgressView().controlSize(.small) }
            Text(state.title).font(appearance.font(17, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            Text(state.message).font(appearance.font(12)).fixedSize(horizontal: false, vertical: true)
            if explainsSources {
                Text("Working on another Mac?").font(appearance.font(12, weight: .semibold))
                Text("Run kanbanana there. It doesn't sync boards between Macs or read cloud-only histories. An API key won't make missing conversations appear.")
                    .font(appearance.font(11)).foregroundStyle(appearance.muted).fixedSize(horizontal: false, vertical: true)
                ForEach(ProviderID.allCases, id: \.self) { provider in
                    Text("\(provider.title): \(store.privacy.disabledProviders.contains(provider.rawValue) ? "Monitoring off" : store.health[provider.rawValue] ?? "Not checked yet")")
                        .font(appearance.font(10)).foregroundStyle(appearance.muted).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Settings…", action: openSettings)
                    Button("Check again") { store.retryStatus() }.disabled(store.scanning || state == .monitoringOff)
                }.controlSize(.small)
                Link("Help finding your first conversation", destination: HelpLinks.topic("your-first-conversation"))
                    .font(appearance.font(11)).fixedSize(horizontal: false, vertical: true)
            } else if state == .filtered {
                Button("Clear filters") { store.selectProject(nil) }
            } else if state == .allParked {
                Button("Open parking lot", action: openParking)
            }
        }.foregroundStyle(appearance.ink).padding(16).frame(maxWidth: 440, alignment: .leading)
            .background(appearance.paper.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
            .padding(10).frame(maxWidth: .infinity)
    }
}
