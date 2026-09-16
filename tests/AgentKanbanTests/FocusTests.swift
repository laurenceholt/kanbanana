import KanbananaCore
import KanbananaServices
import AppKit
import XCTest
@testable import AgentKanban

final class FocusTests: XCTestCase {
    private func card(_ id: String, state: Column = .ready, updated: Double = 100) -> Conversation {
        Conversation(id: id, provider: "codex", nativeID: id, title: id, folder: "", updated: updated,
                     requests: [.init(id: "request", text: "Build it", time: updated)], state: state,
                     reason: "", response: "", eventID: "event", eventTime: updated, url: "")
    }

    @MainActor func testFocusIncludesAllProjectsAndIgnoresHiddenFilters() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = await BoardStore.loaded(root: root, start: false)
        let first = Project(name: "First"), second = Project(name: "Second")
        try await store.installFixture { state in state.projects = [first, second] }
        try await store.installFixture { state in state.cards = [card("older"), card("newer", updated: 200), card("parked"), card("running", state: .running)] }
        var a = Disposition(); a.projectID = first.id
        var b = Disposition(); b.projectID = second.id
        var parked = a; parked.parked = true
        try await store.installFixture { state in state.dispositions = ["older": a, "newer": b, "parked": parked] }
        store.selectedProject = first.id; store.search = "no matches"; store.parking = true
        XCTAssertTrue(store.visible.isEmpty)
        XCTAssertEqual(store.focusCards(in: .ready).map(\.id), ["newer", "older"])
        XCTAssertEqual(store.focusCards(in: .running).map(\.id), ["running"])
        XCTAssertEqual(store.focusCards(in: .ready).count, store.count(.ready))
    }

    @MainActor func testFocusTracksManualMovesAndNewRequests() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = await BoardStore.loaded(root: root, start: false)
        var c = card("work")
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 100))
        store.mark(c, .dealtWith)
        XCTAssertTrue(store.focusCards(in: .ready).isEmpty)
        XCTAssertEqual(store.focusCards(in: .dealtWith).map(\.id), [c.id])
        store.mark(c, .todo)
        XCTAssertEqual(store.focusCards(in: .todo).map(\.id), [c.id])
        c.requests.append(.init(id: "next", text: "Another round", time: 201))
        c.state = .running; c.updated = 201; c.eventTime = 201; c.eventID = "started"
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 201))
        XCTAssertTrue(store.focusCards(in: .todo).isEmpty)
        XCTAssertEqual(store.focusCards(in: .running).map(\.id), [c.id])
        c.state = .ready; c.updated = 202; c.eventTime = 202; c.eventID = "delivered"
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 202))
        XCTAssertEqual(store.focusCards(in: .ready).map(\.id), [c.id])
    }

    func testNarrowFrameFitsShortAndSecondaryDisplaysWithoutChangingFullBoardKey() {
        let secondary = NSRect(x: -1440, y: -100, width: 1440, height: 800)
        let previous = NSRect(x: -1400, y: 80, width: 1000, height: 600)
        let focus = BoardLayout.focus.initialFrame(beside: previous, on: secondary)
        XCTAssertEqual(focus.size, NSSize(width: 300, height: 740))
        XCTAssertEqual(focus.maxX, previous.maxX)
        XCTAssertTrue(secondary.contains(focus))
        let small = NSRect(x: 0, y: 0, width: 1024, height: 650)
        XCTAssertTrue(small.contains(BoardLayout.focus.fitting(focus, on: small)))
        XCTAssertEqual(BoardLayout.columns.frameName, "AgentKanbanBoard")
        XCTAssertEqual(BoardLayout.projects.frameName, BoardLayout.columns.frameName)
        XCTAssertNotEqual(BoardLayout.focus.frameName, BoardLayout.columns.frameName)
    }
}
