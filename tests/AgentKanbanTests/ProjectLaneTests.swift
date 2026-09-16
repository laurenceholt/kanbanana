import XCTest
@testable import AgentKanban

final class ProjectLaneTests: XCTestCase {
    func testPinnedHeaderUsesActualFramesAndYieldsToNextProject() {
        let order = ["math", "boats"]
        XCTAssertNil(PinnedLaneHeader.resolve(order: order, frames: ["math": .init(x: 0, y: 0, width: 800, height: 40)]))
        XCTAssertEqual(PinnedLaneHeader.resolve(order: order, frames: ["math": .init(x: 0, y: -100, width: 800, height: 40), "boats": .init(x: 0, y: 20, width: 800, height: 40)]), PinnedLaneHeader(id: "math", offset: -20))
        XCTAssertEqual(PinnedLaneHeader.resolve(order: order, frames: ["math": .init(x: 0, y: -200, width: 800, height: 40), "boats": .init(x: 0, y: -1, width: 800, height: 40)]), PinnedLaneHeader(id: "boats", offset: 0))
        XCTAssertNil(PinnedLaneHeader.resolve(order: ["new-project"], frames: ["math": .init(x: 0, y: -100, width: 800, height: 40)]), "Filtering must not pin a project that is no longer shown")
    }
    private func card(_ id: String, time: Double, provider: String = "codex", state: Column = .ready) -> Conversation {
        Conversation(id: id, provider: provider, nativeID: id, title: "Build interactive", folder: "/example", updated: time, requests: [.init(id: "request-\(id)", text: "Update \(id)", time: time)], state: state, reason: "", response: "", eventID: id, eventTime: time, url: "\(provider)://threads/\(id)")
    }
    func testLanesUseLatestSourceActivityAndKeepEveryConversation() {
        let math = Project(name: "Math"), otherMath = Project(name: "Math"), boats = Project(name: "Boats")
        let cards = [card("math1", time: 10), card("boats", time: 20), card("math2", time: 30, provider: "claude", state: .running), card("otherMath", time: 15), card("unassigned", time: 5, state: .unknown)]
        let assignments = ["math1": math.id, "math2": math.id, "boats": boats.id, "otherMath": otherMath.id]
        let dispositions = assignments.mapValues { Disposition(projectID: $0) }
        let lanes = ProjectLane.make(visible: cards, allCards: cards, projects: [boats, otherMath, math], dispositions: dispositions)
        XCTAssertEqual(lanes.map { $0.project?.id }, [math.id, boats.id, otherMath.id, nil])
        XCTAssertEqual(lanes[0].cards.map(\.id), ["math2", "math1"])
        XCTAssertEqual(lanes[0].latestActivity, 30)
        XCTAssertEqual(Set(lanes.flatMap(\.cards).map(\.id)).count, cards.count)
        XCTAssertEqual(lanes.flatMap(\.cards).count, cards.count)
        XCTAssertEqual(lanes.last?.cards.first?.state, .unknown)
        XCTAssertEqual(Set(lanes.map(\.id)).count, 4)
    }
    func testSearchKeepsProjectActivityOrderAndParkedActivityDoesNotPromoteLane() {
        let math = Project(name: "Math"), boats = Project(name: "Boats"), empty = Project(name: "Empty")
        let oldMath = card("oldMath", time: 5), newMath = card("newMath", time: 40), boat = card("boat", time: 20), parkedBoat = card("parkedBoat", time: 99)
        var dispositions = ["oldMath": Disposition(projectID: math.id), "newMath": Disposition(projectID: math.id), "boat": Disposition(projectID: boats.id), "parkedBoat": Disposition(projectID: boats.id)]
        dispositions["parkedBoat"]?.parked = true
        let lanes = ProjectLane.make(visible: [boat, oldMath], allCards: [oldMath, newMath, boat, parkedBoat], projects: [math, boats, empty], dispositions: dispositions)
        XCTAssertEqual(lanes.map { $0.project?.id }, [math.id, boats.id])
        XCTAssertEqual(lanes.flatMap(\.cards).map(\.id), [oldMath.id, boat.id])
        XCTAssertEqual(lanes.map(\.latestActivity), [40, 20])
    }
    @MainActor func testLaneDropsMoveOnlyAssignmentAndRequestedStatus() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let math = Project(name: "Math", note: "Ship the installer"), boats = Project(name: "Boats")
        let card = card("task", time: Date().timeIntervalSince1970)
        store.saved.projects = [math, boats]; store.saved.cards = [card]
        store.assign(card, to: math.id)
        let original = store.saved
        XCTAssertTrue(store.moveToLane(card, projectID: math.id, column: .ready))
        XCTAssertEqual(store.saved, original, "Same-cell drops must not create a manual override")
        XCTAssertFalse(store.moveToLane(card, projectID: boats.id, column: .running))
        XCTAssertFalse(store.moveToLane(card, projectID: "missing", column: .dealtWith))
        XCTAssertFalse(store.moveToLane(card, projectID: nil, column: .ready))
        XCTAssertEqual(store.saved, original)
        XCTAssertTrue(store.moveToLane(card, projectID: boats.id, column: .dealtWith))
        XCTAssertEqual(store.disposition(card).projectID, boats.id)
        XCTAssertTrue(store.disposition(card).assignmentLocked)
        XCTAssertEqual(store.column(card), .dealtWith)
        XCTAssertEqual(store.saved.cards, original.cards)
        XCTAssertEqual(store.saved.projects, original.projects)
        XCTAssertEqual(store.saved.summaries, original.summaries)
    }
}
