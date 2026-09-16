import XCTest
@testable import AgentKanban

final class PriorityTests: XCTestCase {
    private func card(_ id: String, time: Double = 100, state: Column = .ready) -> Conversation {
        Conversation(id: id, provider: "codex", nativeID: id, title: "Review \(id)", folder: "/example", updated: time,
                     requests: [.init(id: "request", text: "Build it", time: time)], state: state,
                     reason: "", response: "", eventID: "delivered", eventTime: time, url: "")
    }

    @MainActor func testPriorityIsIndependentOfEveryStateAndOldBoardsDecode() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let legacy = Data(#"{"assignmentLocked":true,"parked":false,"parkedManually":false,"restoredAt":0}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(Disposition.self, from: legacy).priority)
        let project = Project(name: "Project", note: "Near-term goal")
        store.saved.projects = [project]
        for state in Column.allCases {
            let c = card(state.rawValue, state: state)
            store.saved.cards.append(c)
            var d = Disposition(projectID: project.id, assignmentLocked: true)
            d.todoNote = "Next round"
            if state == .todo { d.manualColumn = .todo; d.todoRequestID = c.requests.last?.id }
            if state == .dealtWith { d.acknowledgedRevision = c.revision }
            store.saved.dispositions[c.id] = d
            let previous = store.column(c)
            store.togglePriority(c.id)
            XCTAssertEqual(store.disposition(c).priority, true)
            XCTAssertEqual(store.column(c), previous)
            store.togglePriority(c.id)
            XCTAssertEqual(store.disposition(c), d, "Unstarring restores every disposition field")
        }
        XCTAssertEqual(store.saved.projects, [project])
        XCTAssertNil(store.todoNoteCard, "Priority does not open a note editor or start work")
    }

    @MainActor func testPrioritySurvivesNewRequestsParkingAndRelaunch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        var c = card("important")
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 100))
        store.togglePriority(c.id)
        store.mark(c, .dealtWith)
        c.requests.append(.init(id: "next", text: "Another round", time: 200))
        c.updated = 200; c.eventTime = 200; c.eventID = "started"; c.state = .running
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 200))
        XCTAssertEqual(store.column(c), .running)
        XCTAssertEqual(store.disposition(c).priority, true)
        store.park(c, true)
        store.persist()
        let restored = BoardStore(root: root, start: false)
        XCTAssertEqual(restored.disposition(c).priority, true)
        XCTAssertTrue(restored.disposition(c).parked)
        restored.togglePriority(c.id)
        XCTAssertTrue(restored.disposition(c).parked, "Unstarring must not restore parked work")
        restored.persist()
        XCTAssertNil(BoardStore(root: root, start: false).disposition(c).priority)
    }

    @MainActor func testAllFlatListsUsePriorityThenActivityWithStableTies() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let cards = [card("newest", time: 400), card("b", time: 200), card("oldest", time: 10), card("a", time: 200)]
        store.saved.cards = cards
        for id in ["oldest", "b", "a"] { store.togglePriority(id) }
        XCTAssertEqual(store.visible.map(\.id), ["a", "b", "oldest", "newest"])
        XCTAssertEqual(store.focusCards(in: .ready).map(\.id), store.visible.map(\.id))
        store.search = "Review"
        XCTAssertEqual(store.visible.map(\.id), ["a", "b", "oldest", "newest"])
        for c in cards { store.park(c, true) }
        store.parking = true
        XCTAssertEqual(store.visible.map(\.id), ["a", "b", "oldest", "newest"])
        XCTAssertTrue(store.focusCards(in: .ready).isEmpty, "Priority does not bypass the parking filter")
        store.togglePriority("oldest")
        XCTAssertEqual(store.visible.map(\.id), ["a", "b", "newest", "oldest"])
    }

    func testPriorityLeadsProjectLanesAndStaysOutsideFoldedStacks() {
        let old = Project(name: "Older"), new = Project(name: "Newer")
        let cards = [card("new", time: 500), card("old-a", time: 50), card("old-b", time: 40), card("priority", time: 10)]
        let projects = ["new": new.id, "old-a": old.id, "old-b": old.id, "priority": old.id]
        var dispositions = projects.mapValues { Disposition(projectID: $0) }
        dispositions["priority"]?.priority = true
        let lanes = ProjectLane.make(visible: cards, allCards: cards, projects: [new, old], dispositions: dispositions)
        XCTAssertEqual(lanes.map { $0.project?.id }, [old.id, new.id])
        XCTAssertEqual(lanes[0].cards.map(\.id), ["priority", "old-a", "old-b"])
        for expanded: Set<String> in [[], [old.id]] {
            let rows = ProjectStackRow.rows(cards: cards, projects: projects, stacked: true, expanded: expanded, priorityIDs: ["priority"])
            XCTAssertEqual(rows.first?.id, "card:priority", "The star must remain accessible outside a project pile")
            XCTAssertEqual(Set(rows.flatMap(\.conversations).map(\.id)), Set(cards.map(\.id)))
            XCTAssertEqual(rows.flatMap(\.conversations).count, cards.count)
        }
        dispositions["priority"]?.parked = true
        let filtered = ProjectLane.make(visible: Array(cards.dropLast()), allCards: cards, projects: [old, new], dispositions: dispositions)
        XCTAssertEqual(filtered.map { $0.project?.id }, [new.id, old.id], "A hidden parked priority must not promote the lane")
    }
}
