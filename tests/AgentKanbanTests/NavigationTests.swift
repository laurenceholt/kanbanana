import KanbananaCore
import KanbananaServices
import XCTest
@testable import AgentKanban

final class NavigationTests: XCTestCase {
    func card(_ provider: String, _ id: String, url: String) -> Conversation {
        Conversation(id: "\(provider):\(id)", provider: provider, nativeID: id, title: "Renamed conversation", folder: "/example", updated: 0, requests: [], state: .ready, reason: "", response: "", eventID: "", eventTime: 0, url: url)
    }

    func testSavedLocalClaudeCardUsesExactSessionInsteadOfCloudRoute() throws {
        let id = "local_550e8400-e29b-41d4-a716-446655440000"
        let original = card("claude", id, url: "claude://code/\(id)")
        let restored = try JSONDecoder().decode(Conversation.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.navigationURL?.absoluteString, "claude://code/continue?session=\(id)")
        var another = restored
        another.nativeID = "local_550e8400-e29b-41d4-a716-446655440001"
        XCTAssertNotEqual(another.navigationURL, restored.navigationURL)
    }

    func testCodexAndCloudClaudeRoutesArePreserved() {
        for (provider, id, url) in [("codex", "550e8400-e29b-41d4-a716-446655440000", "codex://threads/550e8400-e29b-41d4-a716-446655440000"), ("claude", "session_cloud123", "claude://code/session_cloud123")] {
            XCTAssertEqual(card(provider, id, url: url).navigationURL?.absoluteString, url)
        }
    }

    func testInvalidLocalIDsAndProviderMismatchDoNotNavigateElsewhere() {
        for id in ["local_", "local_abc?session=last", "local_abc/../new"] {
            XCTAssertNil(card("claude", id, url: "claude://code/\(id)").navigationURL)
        }
        XCTAssertNil(card("claude", "session_test", url: "codex://threads/test").navigationURL)
    }
}
