import Foundation
import Testing
import KanbananaCore

private func card(_ provider: String = "claude") -> Conversation {
    Conversation(id: provider + ":example", provider: provider, nativeID: "example", title: "Example",
        folder: "/example", updated: 100, requests: [RequestItem(id: "z", text: "Build it", time: 100)],
        state: .running, reason: "Working", eventID: "event", eventTime: 100, url: "")
}

@Test func partialInventoryPreservesEvidenceAndCuration() {
    var saved = SavedState()
    saved.cards = [card(), card("codex")]
    saved.projects = [Project(id: "chosen", name: "Chosen", note: "Keep this goal")]
    saved.dispositions["claude:example"] = Disposition(projectID: "chosen", assignmentLocked: true, todoNote: "Next step")
    let next = BoardReconciler.apply(ProviderSnapshot(provider: .claude, cards: [],
        health: ProviderHealth(.partial, issue: "Access denied"), inventoryComplete: false, knownIDs: [], scannedAt: 200), to: saved)
    #expect(next.cards.first?.state == .running)
    #expect(next.cards.first?.requests == saved.cards.first?.requests)
    #expect(next.cards.first?.observationIssue == "Access denied")
    #expect(next.cards.last == saved.cards.last)
    #expect(next.projects == saved.projects)
    #expect(next.dispositions == saved.dispositions)
}

@Test func onlyCompleteInventoryEstablishesAbsence() {
    var saved = SavedState(); saved.cards = [card()]
    let next = BoardReconciler.apply(ProviderSnapshot(provider: .claude, cards: [], health: ProviderHealth(.connected),
        inventoryComplete: true, knownIDs: [], scannedAt: 200), to: saved)
    #expect(next.cards[0].state == .unknown)
    #expect(next.cards[0].requests == saved.cards[0].requests)
}

@Test func emptyDeltaRenewsHealthWithoutLosingHistory() {
    var saved = SavedState(); var previous = card()
    previous.observationIssue = "Reader timed out"; saved.cards = [previous]
    let next = BoardReconciler.apply(ProviderSnapshot(provider: .claude, cards: [], health: ProviderHealth(.connected),
        inventoryComplete: true, knownIDs: [previous.id], scannedAt: 200, completeHistory: false), to: saved)
    #expect(next.cards[0].observationIssue == nil)
    #expect(next.cards[0].requests == previous.requests)
    #expect(next.cards[0].state == .running)
}

@Test func requestsWithEqualTimestampsRetainSourceOrder() {
    let first = RequestItem(id: "z", text: "Build it", time: 100)
    let second = RequestItem(id: "a", text: "Add labels", time: 100)
    let earlier = RequestItem(id: "x", text: "Plan it", time: 100)
    let live = RequestHistory.merging([first], [second])
    #expect(live.map(\.id) == ["z", "a"])
    let paged = RequestHistory.merging(live, [earlier, first], older: true)
    #expect(paged.map(\.id) == ["x", "z", "a"])
    #expect(RequestHistory.merging(paged, [second]) == paged)
    #expect(RequestHistory.merging([first], [earlier, first, second], older: true).map(\.id) == ["x", "z", "a"])
}

@Test func unreadableObservationPreservesLatestReportUntilNewEvidenceArrives() {
    var saved = SavedState(); var previous = card()
    previous.state = .ready; previous.response = "Built it; tests are pending."
    saved.cards = [previous]
    var failed = card(); failed.observationIssue = "Access denied"
    let next = BoardReconciler.apply(ProviderSnapshot(provider: .claude, cards: [failed], health: ProviderHealth(.partial),
        inventoryComplete: false, knownIDs: [previous.id], scannedAt: 101), to: saved)
    #expect(next.cards[0].response == previous.response)
    var running = card(); running.eventID = "new-request"
    let resumed = BoardReconciler.apply(ProviderSnapshot(provider: .claude, cards: [running], health: ProviderHealth(.connected),
        inventoryComplete: true, knownIDs: [previous.id], scannedAt: 102), to: next)
    #expect(resumed.cards[0].response.isEmpty)
}

@Test func commandsAcknowledgeCurrentRevision() {
    var saved = SavedState(); saved.cards = [card()]
    saved.cards[0].eventID = "new-event"
    saved.apply(.mark("claude:example", .dealtWith), now: 200)
    #expect(saved.dispositions["claude:example"]?.acknowledgedRevision == saved.cards[0].revision)
    saved.apply(.mark("claude:example", .running), now: 200)
    #expect(saved.dispositions["claude:example"]?.acknowledgedRevision == saved.cards[0].revision)
}

@Test func chatGPTCatalogGapPreservesCurationAndNewActivityReactivatesCard() {
    var previous = card("chatgpt")
    previous.requests = []; previous.state = .unknown
    var saved = SavedState(); saved.cards = [previous]
    saved.projects = [Project(id: "chosen", name: "Chosen")]
    saved.dispositions[previous.id] = Disposition(projectID: "chosen", assignmentLocked: true,
        acknowledgedRevision: previous.revision, todoNote: "Keep this", priority: true)
    let absent = BoardReconciler.apply(ProviderSnapshot(provider: .chatgpt, cards: [], health: ProviderHealth(.connected),
        inventoryComplete: false, knownIDs: [], scannedAt: 200), to: saved)
    #expect(absent.cards[0].sourceMissing != true)
    #expect(absent.dispositions == saved.dispositions)
    #expect(Lifecycle.column(absent.cards[0], absent.dispositions[previous.id]!) == .dealtWith)
    var changed = previous
    changed.eventID = "catalog:300"; changed.eventTime = 300; changed.updated = 300
    let resumed = BoardReconciler.apply(ProviderSnapshot(provider: .chatgpt, cards: [changed], health: ProviderHealth(.connected),
        inventoryComplete: false, knownIDs: [previous.id], scannedAt: 301), to: absent)
    let disposition = resumed.dispositions[previous.id]!
    #expect(disposition.acknowledgedRevision == nil)
    #expect(disposition.assignmentLocked && disposition.projectID == "chosen")
    #expect(disposition.todoNote == "Keep this" && disposition.priority == true)
    #expect(Lifecycle.column(resumed.cards[0], disposition) == .unknown)
}
