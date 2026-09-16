import KanbananaCore
import KanbananaServices
import XCTest
@testable import AgentKanban

private actor ReleaseCredentials: CredentialStorage {
    var key: String? = "test-only"
    func status() -> CredentialStatus { key == nil ? .missing : .saved }
    func load() -> String { key ?? "" }
    func save(_ value: String) { key = value }
    func delete() { key = nil }
}
private actor ReleaseSummarizer {
    var calls = 0
    func summarize(_ text: String) -> String { calls += 1; return "Fix labels" }
}
final class ReleaseTests: XCTestCase {
    func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func card(_ id: String) -> Conversation {
        .init(id: id, provider: "codex", nativeID: id, title: "private-title", folder: "/private/folder", updated: 100,
              requests: [.init(id: "r", text: "private-request", time: 100)], state: .ready, reason: "", response: "private-response", eventID: "event", eventTime: 100, url: "codex://threads/\(id)")
    }
    @MainActor func testFreshInstallWaitsForOnboardingBeforeReading() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = await BoardStore.loaded(root: root)
        XCTAssertTrue(store.needsOnboarding)
        XCTAssertTrue(store.health.isEmpty)
        XCTAssertFalse(store.saved.aiEnabled)
        await store.stop()
        let relaunched = await BoardStore.loaded(root: root)
        XCTAssertTrue(relaunched.needsOnboarding)
        XCTAssertTrue(relaunched.health.isEmpty)
    }
    @MainActor func testSavingKeyDoesNotEnableCloudAndDeletionDisablesIt() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let credentials = ReleaseCredentials()
        let store = await BoardStore.loaded(root: root, start: false, credentials: credentials)
        let success = await store.saveKey("test-key")
        XCTAssertTrue(success); XCTAssertFalse(store.saved.aiEnabled)
        try await store.installFixture { state in state.aiEnabled = true }
        await store.deleteKey()
        XCTAssertFalse(store.saved.aiEnabled); XCTAssertEqual(store.credentialStatus, .missing)
        let status = await credentials.status(); XCTAssertEqual(status, .missing)
    }
    @MainActor func testDailyLimitAndProjectExclusionApplyToAllQueuesAndPersist() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let api = ReleaseSummarizer()
        let store = await BoardStore.loaded(root: root, start: false, credentials: ReleaseCredentials(), summarize: { text, _, _ in await api.summarize(text) })
        try await store.installFixture { state in state.cards = [card("excluded"), card("a"), card("b")] }
        var options = PrivacyOptions(); options.dailySummaryLimit = 1; options.excludedSummaryProjects = ["private"]
        try await store.installFixture { state in state.privacy = options }
        try await store.installFixture { state in state.dispositions["excluded"] = Disposition(projectID: "private") }
        store.setAIEnabled(true)
        for _ in 0..<100 { if !store.isSummarizing { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        let calls = await api.calls; XCTAssertEqual(calls, 1)
        XCTAssertNil(store.saved.summaries["excluded:r"])
        XCTAssertEqual(store.summaryAttemptsToday, 1)
        await store.persist()
        let loaded = await BoardStore.loaded(root: root, start: false)
        XCTAssertEqual(loaded.summaryAttemptsToday, 1)
        XCTAssertEqual(loaded.privacy.excludedSummaryProjects, ["private"])
        store.summarizeHistory(store.saved.cards[0])
        for _ in 0..<100 { if !store.isSummarizing { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        let afterHistory = await api.calls; XCTAssertEqual(afterHistory, 1)
    }
    func testBackupsAreBoundedValidPrivateAndExcludeResponses() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = FileBoardRepository(root: root)
        let loaded = try await repository.load()
        var state = SavedState(); state.cards = [card("a")]
        try await repository.save(state, epoch: loaded.epoch, revision: 1)
        let file = root.appendingPathComponent("export.json")
        for i in 0..<10 {
            state.projects = [Project(name: "Project \(i)")]
            try await repository.export(state, to: file)
            _ = try await repository.restore(from: file)
        }
        let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 7)
        for backup in backups {
            XCTAssertEqual(try BoardArchive.decode(Data(contentsOf: backup)).cards.first?.response, "")
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: backup.path)[.posixPermissions] as? Int, 0o600)
        }
        var newer = state; newer.version = 999
        XCTAssertThrowsError(try BoardArchive.decode(JSONEncoder().encode(newer)))
        state.cards.append(card("a"))
        XCTAssertThrowsError(try BoardArchive.decode(JSONEncoder().encode(state)))
    }
    func testUnmanagedBackupDoesNotTriggerContinuousRotationOrGetPruned() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Backups")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manual = folder.appendingPathComponent("board-before-repair.json")
        try Data("keep these original bytes".utf8).write(to: manual)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: manual.path)
        let repository = FileBoardRepository(root: root)
        let loaded = try await repository.load()
        for revision in 1...10 { try await repository.save(SavedState(), epoch: loaded.epoch, revision: UInt64(revision)) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).count, 2)
        XCTAssertEqual(try String(contentsOf: manual), "keep these original bytes")
    }
    @MainActor func testRestorePreservesPreviousBoardDisablesAIAndKeepsUsage() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        var original = SavedState()
        original.projects = [Project(name: "Original", note: "Keep this note")]
        original.summaryUsage = SummaryUsage(day: SummaryUsage.today(), attempts: 20)
        try BoardArchive.data(original).write(to: root.appendingPathComponent("board.json"))
        let store = await BoardStore.loaded(root: root, start: false)
        await store.persist()
        var incoming = SavedState(); incoming.projects = [Project(name: "Restored")]; incoming.aiEnabled = true
        incoming.summaryUsage = SummaryUsage(day: SummaryUsage.today(), attempts: 0)
        let file = root.appendingPathComponent("export.json")
        try JSONEncoder().encode(incoming).write(to: file)
        await store.restoreBoard(from: file)
        XCTAssertEqual(store.saved.projects.first?.name, "Restored")
        XCTAssertFalse(store.saved.aiEnabled); XCTAssertEqual(store.summaryAttemptsToday, 20)
        let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
        XCTAssertTrue(try backups.contains { try BoardArchive.decode(Data(contentsOf: $0)).projects.first?.note == "Keep this note" })
        try Data("broken".utf8).write(to: file)
        await store.restoreBoard(from: file)
        XCTAssertEqual(store.saved.projects.first?.name, "Restored")
    }
    func testCorruptCurrentBoardIsPreservedDuringRecovery() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("board.json")
        let original = Data("unreadable-original".utf8); try original.write(to: file)
        let repository = FileBoardRepository(root: root)
        do { _ = try await repository.load(); XCTFail("Corrupt board should fail") } catch { }
        XCTAssertEqual(try Data(contentsOf: file), original)
        let incoming = root.appendingPathComponent("export.json")
        try BoardArchive.data(SavedState()).write(to: incoming)
        _ = try await repository.restore(from: incoming)
        let recovery = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Recovery"), includingPropertiesForKeys: nil)
        XCTAssertEqual(recovery.count, 1)
        XCTAssertEqual(try Data(contentsOf: recovery[0]), original)
        let loaded = try await FileBoardRepository(root: root).load()
        XCTAssertTrue(loaded.state.cards.isEmpty)
    }
    @MainActor func testDiagnosticsOnlyContainAllowlistedAggregateData() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = await BoardStore.loaded(root: root, start: false)
        try await store.installFixture { state in state.cards = [card("private-id")] }
        try await store.installFixture { state in state.projects = [Project(name: "private-project", note: "private-note")] }
        store.apply(ProviderSnapshot(provider: .codex, cards: [], health: ProviderHealth(.unavailable, issue: "private-secret-error"), inventoryComplete: false, knownIDs: [], scannedAt: 100))
        let report = root.appendingPathComponent("diagnostics.json"); await store.exportDiagnostics(to: report)
        let text = try String(contentsOf: report)
        XCTAssertFalse(text.contains("private-")); XCTAssertFalse(text.contains("/private"))
        XCTAssertTrue(text.contains("unavailable")); XCTAssertTrue(text.contains("captured"))
    }
}
