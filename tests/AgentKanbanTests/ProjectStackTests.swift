import XCTest
@testable import AgentKanban

final class ProjectStackTests: XCTestCase {
    private func card(_ id: String, provider: String = "codex", title: String = "Build interactive", state: Column = .ready) -> Conversation {
        Conversation(id: id, provider: provider, nativeID: id, title: title, folder: "/example", updated: 1_800_000_000, requests: [.init(id: "request-\(id)", text: "Update \(id)", time: 1_800_000_000)], state: state, reason: "", response: "", eventID: id, eventTime: 1_800_000_000, url: "\(provider)://threads/\(id)")
    }
    func testStackSpreadAndUnstackPreserveDistinctCrossProviderCards() {
        // Same titles must not merge. Interleaved projects return to their
        // original order when unstacked, including unrelated unassigned cards.
        let cards = [card("a"), card("b"), card("c", provider: "claude"), card("d"), card("e"), card("f")]
        let projects = ["a": "math", "b": "boats", "c": "math", "d": "boats"]
        let folded = ProjectStackRow.rows(cards: cards, projects: projects, stacked: true)
        XCTAssertEqual(folded.count, 4)
        XCTAssertEqual(folded.flatMap(\.conversations).map(\.id), ["a", "c", "b", "d", "e", "f"])
        let spread = ProjectStackRow.rows(cards: cards, projects: projects, stacked: true, expanded: ["math"])
        XCTAssertEqual(spread.count, 6)
        for rows in [folded, spread] {
            let restored = rows.flatMap(\.conversations)
            XCTAssertEqual(Set(restored.map(\.id)).count, cards.count)
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: restored.map { ($0.id, $0) }), Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) }))
            XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
        }
        XCTAssertEqual(ProjectStackRow.rows(cards: cards, projects: projects, stacked: false, expanded: ["math"]).flatMap(\.conversations), cards)
    }
    @MainActor func testStacksFollowVisibleStatusAndProjectChangesWithoutSavingGrouping() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        let math = Project(name: "Math", note: "Install the builder"), boats = Project(name: "Boats")
        let first = card("first"), second = card("second", title: "Fix dragging"), running = card("running", state: .running)
        store.saved.projects = [math, boats]
        store.saved.cards = [first, second, running]
        for card in store.cards { store.assign(card, to: math.id) }
        func readyRows() -> [ProjectStackRow] {
            let cards = store.visible.filter { store.column($0) == .ready }
            let projects = Dictionary(uniqueKeysWithValues: cards.compactMap { c in store.project(c).map { (c.id, $0.id) } })
            return ProjectStackRow.rows(cards: cards, projects: projects, stacked: true)
        }
        let saved = store.saved
        XCTAssertEqual(readyRows().count, 1)
        XCTAssertEqual(readyRows().flatMap(\.conversations).count, 2)
        XCTAssertEqual(store.saved, saved)
        store.mark(first, .dealtWith)
        XCTAssertEqual(readyRows().flatMap(\.conversations).map(\.id), [second.id])
        store.mark(first, .ready)
        store.search = "dragging"
        XCTAssertEqual(readyRows().flatMap(\.conversations).map(\.id), [second.id])
        store.search = ""
        store.assign(second, to: boats.id)
        XCTAssertEqual(readyRows().count, 2)
        store.selectProject(math.id)
        XCTAssertEqual(readyRows().flatMap(\.conversations).map(\.id), [first.id])
        XCTAssertEqual(store.saved.cards, saved.cards)
        XCTAssertEqual(store.saved.projects, saved.projects)
    }
}
