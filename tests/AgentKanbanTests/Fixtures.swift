import Foundation
import KanbananaCore
import KanbananaServices
@testable import AgentKanban

/// Compatibility builder for the original lifecycle scenarios. It converts their
/// human-readable test labels at the boundary; production never parses UI strings.
struct Snapshot {
    var cards: [Conversation]
    var health: [String: String]
    var scannedAt: Double
}

@MainActor extension BoardStore {
    func apply(_ fixture: Snapshot) {
        for provider in ProviderID.allCases where fixture.health[provider.rawValue] != nil {
            let text = fixture.health[provider.rawValue]!
            let health = ProviderHealth(text.hasPrefix("Connected") ? .connected : .unavailable, issue: text.hasPrefix("Connected") ? nil : text.replacingOccurrences(of: "Unavailable · ", with: ""))
            var cards = fixture.cards.filter { $0.provider == provider.rawValue }
            for i in cards.indices where ["History temporarily unavailable", "History unavailable"].contains(cards[i].reason) {
                cards[i].observationIssue = cards[i].reason
            }
            apply(ProviderSnapshot(provider: provider, cards: cards, health: health,
                inventoryComplete: health.status == .connected, knownIDs: Set(cards.map(\.id)), scannedAt: fixture.scannedAt))
        }
    }
    /// Exercise the supported import path rather than reaching through private state.
    func installFixture(_ edit: (inout SavedState) -> Void) async throws {
        var state = saved
        edit(&state)
        let file = root.appendingPathComponent("test-fixture-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try BoardArchive.data(state).write(to: file)
        await restoreBoard(from: file)
        if state.aiEnabled { setAIEnabled(true) }
    }
}
