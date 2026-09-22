import Foundation
import Testing
import KanbananaCore

private let day = 86400.0
private let now = 1_800_000_000.0

private func conversation(_ provider: ProviderID) -> Conversation {
    Conversation(id: provider.rawValue + ":example", provider: provider.rawValue, nativeID: "example",
        title: "Example", folder: "/example", updated: now - 8 * day,
        requests: [RequestItem(id: "request", text: "Build it", time: now - 8 * day)],
        state: .unknown, reason: "Conversation not found in source history", eventID: "event",
        eventTime: now - 8 * day, url: provider.rawValue + "://example")
}

private func inventory(_ provider: ProviderID, cards: [Conversation] = [], complete: Bool = true,
                       health: ProviderHealth.Status = .connected, at: Double = now) -> ProviderSnapshot {
    ProviderSnapshot(provider: provider, cards: cards, health: ProviderHealth(health),
        inventoryComplete: complete, knownIDs: Set(cards.map(\.id)), scannedAt: at)
}

@Test(arguments: ProviderID.allCases)
func oldMissingCardsParkWithoutLosingCurationOrCachedHistory(provider: ProviderID) throws {
    // Reproduce an older cache with no sourceMissing field and an unknown state.
    let original = conversation(provider)
    let legacy = try JSONEncoder().encode(original)
    #expect(!String(decoding: legacy, as: UTF8.self).contains("sourceMissing"))
    var saved = SavedState(); saved.cards = [try JSONDecoder().decode(Conversation.self, from: legacy)]
    saved.projects = [Project(id: "p", name: "Example", note: "Our goal")]
    saved.dispositions[original.id] = Disposition(projectID: "p", assignmentLocked: true,
        acknowledgedRevision: original.revision, todoNote: "Keep this note", priority: true)
    saved.summaries[original.id + ":request"] = Summary(text: "Build it", inputHash: "hash")
    let scan = inventory(provider)
    let next = BoardReconciler.apply(scan, to: saved)
    #expect(next.cards[0].sourceMissing == true)
    #expect(next.cards[0].navigationURL == nil)
    #expect(next.cards[0].requests == original.requests)
    var expected = saved.dispositions[original.id]!
    expected.parked = true
    #expect(next.dispositions[original.id] == expected)
    #expect(next.projects == saved.projects)
    #expect(next.summaries == saved.summaries)
    #expect(BoardReconciler.apply(scan, to: next) == next)
}

@Test(arguments: [ProviderHealth.Status.connected, .partial, .unavailable, .disabled])
func incompleteInventoriesNeverParkMissingCards(health: ProviderHealth.Status) {
    var saved = SavedState(); saved.cards = [conversation(.claude)]
    let next = BoardReconciler.apply(inventory(.claude, complete: false, health: health), to: saved)
    #expect(next.cards[0].sourceMissing == nil)
    #expect(next.dispositions[next.cards[0].id]?.parked != true)
}

@Test func completeInventoryCanConfirmAbsenceDespiteAnotherUnreadableTranscript() {
    var saved = SavedState(); saved.cards = [conversation(.claude)]
    let next = BoardReconciler.apply(inventory(.claude, health: .partial), to: saved)
    #expect(next.cards[0].sourceMissing == true)
    #expect(next.dispositions[next.cards[0].id]?.parked == true)
}

@Test func existingUnclearAndUnreadableConversationsStayOnBoard() {
    for unreadable in [false, true] {
        var card = conversation(.claude)
        card.reason = "No recent execution signal"
        card.observationIssue = unreadable ? "Access denied" : nil
        var saved = SavedState(); saved.cards = [card]
        let next = BoardReconciler.apply(inventory(.claude, cards: [card], health: unreadable ? .partial : .connected), to: saved)
        #expect(next.cards[0].sourceMissing == nil)
        #expect(next.dispositions[card.id]?.parked == false)
    }
}

@Test func missingCardsRespectToDoAndManualRestoration() {
    var saved = SavedState(); let card = conversation(.codex); saved.cards = [card]
    saved.apply(.mark(card.id, .todo), now: now)
    saved.apply(.todoNote(card.id, "Next round"), now: now)
    let reminder = BoardReconciler.apply(inventory(.codex), to: saved)
    #expect(reminder.dispositions == saved.dispositions)
    #expect(Lifecycle.column(reminder.cards[0], reminder.dispositions[card.id]!) == .todo)
    saved.apply(.mark(card.id, .dealtWith), now: now)
    saved = BoardReconciler.apply(inventory(.codex), to: saved)
    #expect(saved.dispositions[card.id]?.parked == true)
    saved.apply(.park(card.id, false), now: now)
    let restored = BoardReconciler.apply(inventory(.codex, at: now + 7 * day - 1), to: saved)
    #expect(restored.dispositions[card.id]?.parked == false)
    let aged = BoardReconciler.apply(inventory(.codex, at: now + 7 * day), to: restored)
    #expect(aged.dispositions[card.id]?.parked == true)
    #expect(aged.dispositions[card.id]?.todoNote == "Next round")
}

@Test func recentMissingConversationsWaitUntilSevenDaysOfInactivity() {
    var saved = SavedState(); var card = conversation(.claude)
    card.updated = now - 7 * day + 1; saved.cards = [card]
    let recent = BoardReconciler.apply(inventory(.claude), to: saved)
    #expect(recent.cards[0].sourceMissing == true)
    #expect(recent.dispositions[card.id]?.parked == false)
    let aged = BoardReconciler.apply(inventory(.claude, at: now + 1), to: recent)
    #expect(aged.dispositions[card.id]?.parked == true)
}

@Test func newActivityRestoresMissingConversationWithoutMergingReplacement() {
    var saved = SavedState(); var original = conversation(.claude)
    saved.cards = [original]
    saved.dispositions[original.id] = Disposition(projectID: "p", assignmentLocked: true, todoNote: "Remember this", priority: true)
    saved = BoardReconciler.apply(inventory(.claude), to: saved)
    var replacement = original
    replacement.id = "claude:replacement"; replacement.nativeID = "replacement"
    replacement.updated = now; replacement.state = .ready
    let replaced = BoardReconciler.apply(inventory(.claude, cards: [replacement]), to: saved)
    #expect(replaced.cards.count == 2)
    #expect(replaced.dispositions[original.id]?.parked == true)
    original.updated = now; original.eventTime = now; original.eventID = "new-event"
    original.state = .running; original.reason = "Working"
    original.requests.append(RequestItem(id: "next-request", text: "Add labels", time: now))
    let resumed = BoardReconciler.apply(inventory(.claude, cards: [original, replacement]), to: replaced)
    let card = resumed.cards.first { $0.id == original.id }!
    #expect(card.sourceMissing == nil)
    #expect(card.navigationURL != nil)
    #expect(resumed.dispositions[card.id]?.parked == false)
    #expect(resumed.dispositions[card.id]?.projectID == "p")
    #expect(resumed.dispositions[card.id]?.assignmentLocked == true)
    #expect(resumed.dispositions[card.id]?.todoNote == "Remember this")
    #expect(resumed.dispositions[card.id]?.priority == true)
}

@Test func ReappearingMetadataClearsAbsenceEvenWhenHistoryIsUnreadable() {
    var saved = SavedState(); var card = conversation(.codex); saved.cards = [card]
    saved = BoardReconciler.apply(inventory(.codex), to: saved)
    card.observationIssue = "Access denied"; card.reason = "History temporarily unavailable"
    let next = BoardReconciler.apply(inventory(.codex, cards: [card], health: .partial), to: saved)
    #expect(next.cards[0].sourceMissing == nil)
    #expect(next.cards[0].observationIssue == "Access denied")
    #expect(next.cards[0].reason == "History temporarily unavailable")
}
