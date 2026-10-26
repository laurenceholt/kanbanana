import KanbananaCore
import KanbananaServices
import XCTest
@testable import AgentKanban

final class EmptyBoardTests: XCTestCase {
    @MainActor func testFirstInstallDistinguishesScanningEmptyDisabledAndUnreadable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = await BoardStore.loaded(root: root, start: false, credentials: DemoCredentials())
        store.scanning = true
        XCTAssertEqual(store.emptyBoardState(focusColumn: .ready), .scanning)
        store.scanning = false
        XCTAssertEqual(store.emptyBoardState(focusColumn: .ready), .noLocalConversations)
        store.apply(ProviderSnapshot(provider: .codex, cards: [], health: ProviderHealth(.accessDenied), inventoryComplete: false, knownIDs: [], scannedAt: 100, completeHistory: false))
        XCTAssertEqual(store.emptyBoardState(), .connectionProblem)
        try await store.installFixture { state in
            var privacy = PrivacyOptions(); privacy.disabledProviders = ["claude", "codex"]; state.privacy = privacy
        }
        XCTAssertEqual(store.emptyBoardState(), .monitoringOff)
        await store.stop()
    }

    @MainActor func testEmptyStatusIsNotMistakenForAnEmptyInstallation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var fixture = DemoData.state()
        fixture.cards = fixture.cards.filter { $0.state == .running }
        let store = await BoardStore.loaded(root: root, start: false, initialState: fixture, credentials: DemoCredentials())
        XCTAssertEqual(store.emptyBoardState(focusColumn: .ready), .columnEmpty(.ready))
        store.search = "no matches"; store.selectedProject = "hidden-filter"; store.parking = true
        XCTAssertEqual(store.emptyBoardState(), .filtered)
        XCTAssertEqual(store.emptyBoardState(focusColumn: .ready), .columnEmpty(.ready))
        store.selectProject(nil)
        XCTAssertEqual(store.emptyBoardState(), .parkingEmpty)
        await store.stop()
    }

    @MainActor func testAllParkedOffersRecoveryInsteadOfStartingNewWork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var fixture = DemoData.state()
        for card in fixture.cards { fixture.dispositions[card.id, default: Disposition()].parked = true }
        let store = await BoardStore.loaded(root: root, start: false, initialState: fixture, credentials: DemoCredentials())
        XCTAssertEqual(store.emptyBoardState(), .allParked)
        XCTAssertEqual(store.emptyBoardState(focusColumn: .ready), .allParked)
        store.parking = true
        XCTAssertFalse(store.visible.isEmpty)
        await store.stop()
    }
}
