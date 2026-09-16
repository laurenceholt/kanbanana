import XCTest
@testable import AgentKanban

final class TodoTests: XCTestCase {
    private let now = 1_800_000_000.0
    private func card() -> Conversation {
        Conversation(id: "codex:todo", provider: "codex", nativeID: "todo", title: "Build installer", folder: "/example", updated: now, requests: [.init(id: "request-1", text: "Build it", time: now - 30)], state: .ready, reason: "", response: "", eventID: "delivered", eventTime: now, url: "codex://threads/todo")
    }
    @MainActor func testManualReminderSurvivesPollingNewExecutionEventsAndSourceOutage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        var c = card()
        func apply(_ card: Conversation, healthy: Bool = true, time: Double? = nil) {
            store.apply(.init(cards: [card], health: ["codex": healthy ? "Connected" : "Unavailable"], scannedAt: time ?? now))
        }
        apply(c)
        XCTAssertEqual(store.count(.todo), 0)
        store.mark(c, .todo)
        XCTAssertEqual(store.todoNoteCard?.id, c.id)
        store.todoNoteCard = nil
        store.setTodoNote(c.id, "Check installation on a writer’s Mac")
        for _ in 0..<5 { apply(c) }
        XCTAssertEqual(store.column(try XCTUnwrap(store.cards.first)), .todo)
        XCTAssertNil(store.todoNoteCard, "Background polls must never open the note editor")

        c.eventID = "late-completion"; c.eventTime += 10; c.updated += 10
        apply(c)
        apply(c, healthy: false)
        XCTAssertEqual(store.column(try XCTUnwrap(store.cards.first)), .todo)
        apply(c, time: now + 9 * 86400)
        XCTAssertFalse(store.disposition(c).parked, "Pending personal reminders must remain on the board")
        XCTAssertEqual(store.column(c), .todo)
        XCTAssertEqual(store.disposition(c).todoNote, "Check installation on a writer’s Mac")
    }
    @MainActor func testNewRequestReleasesReminderAndLateNoteSaveDoesNotMoveCardBack() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let old = card()
        store.apply(.init(cards: [old], health: ["codex": "Connected"], scannedAt: now))
        store.mark(old, .todo)
        var next = old
        next.state = .running; next.eventID = "started"; next.eventTime += 60; next.updated += 60
        next.requests.append(.init(id: "request-2", text: "Test the installer", time: now + 60))
        store.apply(.init(cards: [next], health: ["codex": "Connected"], scannedAt: now + 60))
        XCTAssertEqual(store.column(next), .running)
        XCTAssertNil(store.disposition(next).manualColumn)
        XCTAssertNil(store.disposition(next).todoRequestID)
        store.setTodoNote(old.id, "Check installation on a writer’s Mac")
        XCTAssertEqual(store.column(next), .running, "Saving a note from an already-open editor must not requeue the card")
        next.state = .ready; next.eventID = "done"; next.eventTime += 10
        store.apply(.init(cards: [next], health: ["codex": "Connected"], scannedAt: now + 70))
        XCTAssertEqual(store.column(next), .ready)
        XCTAssertNotNil(store.disposition(next).todoNote)
        XCTAssertEqual(store.count(.todo), 0)
    }
    @MainActor func testNotesAndManualPlacementReloadIndependentlyOfProjectGoal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let project = Project(name: "Math", note: "Ship the builder")
        let c = card()
        store.saved.projects = [project]; store.saved.cards = [c]
        store.assign(c, to: project.id)
        store.mark(c, .dealtWith)
        store.mark(c, .todo)
        XCTAssertNil(store.disposition(c).acknowledgedRevision)
        store.setTodoNote(c.id, "  Try installation on a writer’s Mac\n")
        store.search = "writer’s Mac"
        XCTAssertEqual(store.visible.map(\.id), [c.id])
        store.persist()
        let reloaded = BoardStore(root: root, start: false)
        let restored = try XCTUnwrap(reloaded.cards.first)
        XCTAssertEqual(reloaded.column(restored), .todo, "Reconnecting at launch must not hide a manual reminder")
        XCTAssertEqual(reloaded.disposition(restored).todoNote, "Try installation on a writer’s Mac")
        XCTAssertEqual(reloaded.project(restored)?.note, "Ship the builder")
        reloaded.setTodoNote(c.id, " \n")
        XCTAssertNil(reloaded.disposition(restored).todoNote)
        XCTAssertEqual(reloaded.column(restored), .todo, "A blank note is valid")
        reloaded.park(restored, true)
        XCTAssertTrue(reloaded.disposition(restored).parked)
        reloaded.park(restored, false)
        XCTAssertEqual(reloaded.column(restored), .todo)
        reloaded.mark(restored, .dealtWith)
        XCTAssertNotEqual(reloaded.column(restored), .todo)
    }
    func testOldBoardDecodesAndSourcesCannotAssignToDo() throws {
        let legacy = Data(#"{"assignmentLocked":true,"parked":false,"parkedManually":false,"restoredAt":0,"manualColumn":"ready","manualRevision":"old"}"#.utf8)
        let decoded = try JSONDecoder().decode(Disposition.self, from: legacy)
        XCTAssertNil(decoded.todoNote)
        XCTAssertNil(decoded.todoRequestID)
        XCTAssertEqual(decoded.manualColumn, .ready)
        var c = card(); c.state = .todo
        XCTAssertEqual(Lifecycle.column(c, Disposition()), .unknown)
        XCTAssertEqual(Column.board.first, .todo)
        XCTAssertEqual(Column.board.count, 5)
    }
    @MainActor func testLaneDropOffersNoteOnceAndPreservesProjectGoals() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let p = Project(name: "Math", note: "Ship the builder"), other = Project(name: "Writing", note: "Finish the article")
        let c = card()
        store.saved.projects = [p, other]; store.saved.cards = [c]; store.assign(c, to: p.id)
        XCTAssertTrue(store.moveToLane(c, projectID: other.id, column: .todo))
        XCTAssertEqual(store.column(c), .todo)
        XCTAssertEqual(store.disposition(c).projectID, other.id)
        XCTAssertEqual(store.todoNoteCard?.id, c.id)
        store.todoNoteCard = nil
        store.setTodoNote(c.id, "Next pass")
        let placed = store.saved
        XCTAssertTrue(store.moveToLane(c, projectID: other.id, column: .todo))
        XCTAssertEqual(store.saved, placed)
        XCTAssertNil(store.todoNoteCard)
        XCTAssertEqual(store.saved.projects, [p, other])
        XCTAssertEqual(store.saved.cards, [c])
    }
}
