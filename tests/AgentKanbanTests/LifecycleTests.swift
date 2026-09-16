import XCTest
import Combine
@testable import AgentKanban

final class LifecycleTests: XCTestCase {
    let now = 1_800_000_000.0
    func card(state: Column = .ready, age: Double = 0, revision: String = "1") -> Conversation {
        Conversation(id: "codex:test", provider: "codex", nativeID: "test", title: "Build interactive", folder: "/example", updated: now - age, requests: [RequestItem(id: revision, text: "Build it", time: now - age)], state: state, reason: "", response: "", eventID: revision, eventTime: now - age, url: "codex://threads/test")
    }
    func testReplayPreservesAcknowledgementAndAssignment() {
        let c = card()
        var d = Disposition(); d.acknowledgedRevision = c.revision; d.projectID = "manual"; d.assignmentLocked = true
        let result = Lifecycle.reconcile(c, c, d, now: now, healthy: true)
        XCTAssertEqual(Lifecycle.column(c, result), .dealtWith)
        XCTAssertEqual(result.projectID, "manual")
        XCTAssertTrue(result.assignmentLocked)
    }
    func testNewRequestRestoresManuallyParkedCard() {
        let old = card(age: 20), new = card(state: .running, revision: "2")
        var d = Disposition(); d.parked = true; d.parkedManually = true; d.acknowledgedRevision = old.revision
        let result = Lifecycle.reconcile(old, new, d, now: now, healthy: true)
        XCTAssertFalse(result.parked)
        XCTAssertNil(result.acknowledgedRevision)
        XCTAssertEqual(Lifecycle.column(new, result), .running)
    }
    func testParkingAndRestorationTimer() {
        let c = card(age: 8 * 86400)
        XCTAssertTrue(Lifecycle.reconcile(nil, c, Disposition(), now: now, healthy: true).parked)
        var d = Disposition(); d.restoredAt = now - 86400
        XCTAssertFalse(Lifecycle.reconcile(c, c, d, now: now, healthy: true).parked)
    }
    func testUnavailableAndRunningDoNotAutoPark() {
        for state in [Column.running, .unknown] {
            let c = card(state: state, age: 9 * 86400)
            XCTAssertFalse(Lifecycle.reconcile(c, c, Disposition(), now: now, healthy: true).parked)
        }
        let c = card(age: 9 * 86400)
        XCTAssertFalse(Lifecycle.reconcile(c, c, Disposition(), now: now, healthy: false).parked)
    }
    func testOldDelayedEventDoesNotClearUserAction() {
        let current = card(revision: "2"), stale = card(age: 100, revision: "1")
        var d = Disposition(); d.acknowledgedRevision = current.revision
        XCTAssertEqual(Lifecycle.reconcile(current, stale, d, now: now, healthy: true).acknowledgedRevision, current.revision)
    }
    @MainActor func testNoteAssignmentAndParkingSurviveReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        store.addProject("Math")
        let pid = try XCTUnwrap(store.saved.projects.first?.id)
        store.setNote(pid, "Install on writer machines")
        store.setProjectColor(pid, 5)
        store.setProjectSymbol(pid, 6)
        let c = card(); store.saved.cards = [c]; store.assign(c, to: pid); store.park(c, true); store.persist()
        let reloaded = BoardStore(root: root, start: false)
        XCTAssertEqual(reloaded.saved.projects.first?.note, "Install on writer machines")
        XCTAssertEqual(reloaded.saved.projects.first?.colorIndex, 5)
        XCTAssertEqual(reloaded.saved.projects.first?.symbolIndex, 6)
        XCTAssertTrue(reloaded.disposition(c).assignmentLocked)
        XCTAssertTrue(reloaded.disposition(c).parked)
    }
    @MainActor func testOlderProjectsReceiveColorsWithoutChangingAssignments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let project = Project(name: "Existing project")
        store.saved.projects = [project]
        let c = card(); store.saved.cards = [c]; store.assign(c, to: project.id); store.persist()
        let reloaded = BoardStore(root: root, start: false)
        XCTAssertEqual(reloaded.saved.projects.first?.colorIndex, 0)
        XCTAssertEqual(reloaded.saved.projects.first?.symbolIndex, 0)
        XCTAssertEqual(reloaded.disposition(c).projectID, project.id)
        XCTAssertTrue(reloaded.disposition(c).assignmentLocked)
    }
    @MainActor func testCorruptStateIsNotOverwritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("board.json")
        try Data("invalid".utf8).write(to: file)
        let store = BoardStore(root: root, start: false)
        store.addProject("Should not overwrite"); store.persist()
        XCTAssertEqual(try String(contentsOf: file), "invalid")
        XCTAssertNotNil(store.error)
    }
    @MainActor func testUnchangedPollingDoesNotRepublishOrUndoDrop() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let c = card()
        let snapshot = Snapshot(cards: [c], health: ["codex": "Connected"], scannedAt: now)
        store.apply(snapshot)
        store.mark(c, .dealtWith)
        var publications = 0
        let subscription = store.$saved.dropFirst().sink { _ in publications += 1 }
        for _ in 0..<20 { store.apply(snapshot) }
        XCTAssertEqual(publications, 0)
        XCTAssertEqual(store.column(c), .dealtWith)
        withExtendedLifetime(subscription) {}
    }
    @MainActor func testUnreadableHistoryKeepsRequestsAndRecoversAcknowledgement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let c = card()
        store.apply(Snapshot(cards: [c], health: ["codex": "Connected"], scannedAt: now))
        store.mark(c, .dealtWith)
        var unavailable = c
        unavailable.state = .unknown; unavailable.reason = "History temporarily unavailable"
        unavailable.requests = []; unavailable.eventID = ""; unavailable.eventTime = 0
        store.apply(Snapshot(cards: [unavailable], health: ["codex": "Connected"], scannedAt: now + 1))
        let retained = try XCTUnwrap(store.cards.first)
        XCTAssertEqual(retained.requests, c.requests)
        XCTAssertEqual(retained.state, .ready)
        XCTAssertNotNil(retained.observationIssue)
        XCTAssertEqual(store.column(retained), .dealtWith, "A temporary source outage must not undo manual acknowledgement")
        store.apply(Snapshot(cards: [c], health: ["codex": "Connected"], scannedAt: now + 2))
        XCTAssertEqual(store.column(try XCTUnwrap(store.cards.first)), .dealtWith)
        XCTAssertNil(store.cards.first?.observationIssue)
    }
    @MainActor func testProviderOutageKeepsCompletedCardsAndCurationAcrossRecoveryAndRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let original = (0..<24).map { index in
            var c = card(); c.id = "codex:\(index)"; c.nativeID = "\(index)"; return c
        }
        store.apply(.init(cards: original, health: ["codex": "Connected"], scannedAt: now))
        store.mark(original[0], .dealtWith)
        store.mark(original[1], .todo); store.setTodoNote(original[1].id, "Next round")
        store.park(original[2], true)
        let dispositions = store.saved.dispositions
        store.apply(.init(cards: [], health: ["codex": "Unavailable · History database busy"], scannedAt: now + 1))
        XCTAssertEqual(store.cards.count, 24)
        XCTAssertTrue(store.cards.allSatisfy { $0.state == .ready && $0.observationIssue == "History database busy" })
        XCTAssertEqual(store.count(.unknown), 0)
        XCTAssertEqual(store.sourceWarnings, ["Codex updates paused · History database busy"])
        XCTAssertEqual(store.saved.dispositions, dispositions)
        store.persist()
        let reloaded = BoardStore(root: root, start: false)
        XCTAssertEqual(reloaded.cards, store.cards)
        XCTAssertFalse(reloaded.sourceWarnings.isEmpty, "A restart must not conceal the saved observation failure")
        reloaded.apply(.init(cards: original, health: ["codex": "Connected"], scannedAt: now + 2))
        XCTAssertTrue(reloaded.sourceWarnings.isEmpty)
        XCTAssertTrue(reloaded.cards.allSatisfy { $0.observationIssue == nil })
        XCTAssertEqual(reloaded.saved.dispositions, dispositions)
    }
    @MainActor func testOutageDoesNotPretendAnAgentIsStillRunningOrAutoParkStaleCards() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let c = card(state: .running)
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: now))
        store.apply(.init(cards: [], health: ["codex": "Unavailable · File access denied"], scannedAt: now + 1))
        let retained = try XCTUnwrap(store.cards.first)
        XCTAssertEqual(retained.state, .running, "Keep the last observation separately from its availability")
        XCTAssertEqual(store.column(retained), .unknown, "Do not claim a live run during a connection outage")
        var ready = card(age: 6 * 86400)
        store.apply(.init(cards: [ready], health: ["codex": "Connected"], scannedAt: now))
        ready.state = .unknown; ready.reason = "History temporarily unavailable"; ready.requests = []; ready.eventID = ""; ready.eventTime = 0
        store.apply(.init(cards: [ready], health: ["codex": "Connected"], scannedAt: now + 2 * 86400))
        XCTAssertFalse(store.disposition(ready).parked, "An unreadable history cannot supply evidence for automatic parking")
    }
    @MainActor func testRestartRetainsLastKnownStateAndIncludesOldParkedCardsInReaderRequest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let c = card(age: 30 * 86400)
        store.saved.cards = [c]; store.park(c, true); store.mark(c, .dealtWith); store.persist()
        let reloaded = BoardStore(root: root, start: false)
        let retained = try XCTUnwrap(reloaded.cards.first)
        XCTAssertEqual(retained.state, .ready)
        XCTAssertEqual(reloaded.column(retained), .dealtWith)
        XCTAssertTrue(reloaded.disposition(retained).parked)
        let args = BoardStore.readerArguments(script: "/example/reader.py", days: 14, parentPID: 123, trackedIDs: reloaded.cards.map(\.id))
        let flag = try XCTUnwrap(args.firstIndex(of: "--tracked-id"))
        XCTAssertEqual(args[flag + 1], c.id, "Old parked conversations must cross the process boundary for rechecking")
    }
    @MainActor func testMissingTrackedCardReportsAbsenceAndRecoversWithoutLosingCuration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let c = card()
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: now))
        store.mark(c, .todo); store.setTodoNote(c.id, "Another pass")
        let disposition = store.disposition(c)
        store.apply(.init(cards: [], health: ["codex": "Connected"], scannedAt: now + 1))
        let missing = try XCTUnwrap(store.cards.first)
        XCTAssertEqual(missing.state, .unknown)
        XCTAssertEqual(missing.reason, "Conversation not found in source history")
        XCTAssertEqual(store.column(missing), .todo)
        XCTAssertEqual(store.disposition(missing), disposition)
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: now + 2))
        XCTAssertEqual(store.cards.first?.state, .ready)
        XCTAssertEqual(store.disposition(c), disposition)
    }
    @MainActor func testLaterUnavailableObservationClearsOldRetrySuccess() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        var c = card()
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: now))
        store.statusCheckMessage = "Status checked · all available"
        c.state = .unknown; c.reason = "No recent execution signal"
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: now + 1))
        XCTAssertNil(store.statusCheckMessage)
        XCTAssertEqual(store.column(c), .unknown)
    }
}
