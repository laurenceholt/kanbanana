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
    @MainActor func testFreshInstallWaitsForOnboardingBeforeReading() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root)
        XCTAssertTrue(store.needsOnboarding)
        XCTAssertTrue(store.health.isEmpty)
        XCTAssertFalse(store.saved.aiEnabled)
        store.stop()
        let relaunched = BoardStore(root: root)
        XCTAssertTrue(relaunched.needsOnboarding)
        XCTAssertTrue(relaunched.health.isEmpty)
    }
    @MainActor func testSavingKeyDoesNotEnableCloudAndDeletionDisablesIt() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let credentials = ReleaseCredentials()
        let store = BoardStore(root: root, start: false, credentials: credentials)
        let success = await store.saveKey("test-key")
        XCTAssertTrue(success); XCTAssertFalse(store.saved.aiEnabled)
        store.saved.aiEnabled = true
        await store.deleteKey()
        XCTAssertFalse(store.saved.aiEnabled); XCTAssertEqual(store.credentialStatus, .missing)
        let status = await credentials.status(); XCTAssertEqual(status, .missing)
    }
    @MainActor func testDailyLimitAndProjectExclusionApplyToAllQueuesAndPersist() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let api = ReleaseSummarizer()
        let store = BoardStore(root: root, start: false, credentials: ReleaseCredentials(), summarize: { text, _, _ in await api.summarize(text) })
        store.saved.cards = [card("excluded"), card("a"), card("b")]
        var options = PrivacyOptions(); options.dailySummaryLimit = 1; options.excludedSummaryProjects = ["private"]
        store.saved.privacy = options
        store.saved.dispositions["excluded"] = Disposition(projectID: "private")
        store.setAIEnabled(true)
        for _ in 0..<100 { if !store.isSummarizing { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        let calls = await api.calls; XCTAssertEqual(calls, 1)
        XCTAssertNil(store.saved.summaries["excluded:r"])
        XCTAssertEqual(store.summaryAttemptsToday, 1)
        store.persist()
        let loaded = BoardStore(root: root, start: false)
        XCTAssertEqual(loaded.summaryAttemptsToday, 1)
        XCTAssertEqual(loaded.privacy.excludedSummaryProjects, ["private"])
        store.summarizeHistory(store.saved.cards[0])
        for _ in 0..<100 { if !store.isSummarizing { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        let afterHistory = await api.calls; XCTAssertEqual(afterHistory, 1)
        store.saved.summaryUsage = SummaryUsage(day: "2000-01-01", attempts: 100)
        XCTAssertEqual(store.summaryAttemptsToday, 0)
    }
    func testBackupsAreBoundedValidPrivateAndExcludeResponses() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let persistence = StatePersistence(); let file = root.appendingPathComponent("board.json")
        var state = SavedState(); state.cards = [card("a")]
        XCTAssertTrue(persistence.writeSync(state, to: file))
        for i in 0..<10 { state.projects = [Project(name: "Project \(i)")]; XCTAssertTrue(persistence.backupNow(file)); XCTAssertTrue(persistence.writeSync(state, to: file)) }
        let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 7)
        for backup in backups {
            XCTAssertEqual(try StatePersistence.decode(Data(contentsOf: backup)).cards.first?.response, "")
            let permissions = try FileManager.default.attributesOfItem(atPath: backup.path)[.posixPermissions] as? Int
            XCTAssertEqual(permissions, 0o600)
        }
        let before = try Data(contentsOf: file)
        var newer = state; newer.version = 999
        XCTAssertThrowsError(try StatePersistence.decode(JSONEncoder().encode(newer)))
        state.cards.append(card("a"))
        XCTAssertThrowsError(try StatePersistence.decode(JSONEncoder().encode(state)))
        XCTAssertEqual(try Data(contentsOf: file), before)
    }
    @MainActor func testRestorePreservesPreviousBoardDisablesAIAndKeepsUsage() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        store.saved.projects = [Project(name: "Original", note: "Keep this note")]
        store.saved.summaryUsage = SummaryUsage(day: SummaryUsage.today(), attempts: 20)
        store.persist()
        var incoming = SavedState(); incoming.projects = [Project(name: "Restored")]; incoming.aiEnabled = true
        incoming.summaryUsage = SummaryUsage(day: SummaryUsage.today(), attempts: 0)
        let file = root.appendingPathComponent("export.json")
        try JSONEncoder().encode(incoming).write(to: file)
        store.restoreBoard(from: file)
        XCTAssertEqual(store.saved.projects.first?.name, "Restored")
        XCTAssertFalse(store.saved.aiEnabled); XCTAssertEqual(store.summaryAttemptsToday, 20)
        let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
        XCTAssertTrue(try backups.contains { try StatePersistence.decode(Data(contentsOf: $0)).projects.first?.note == "Keep this note" })
        try Data("broken".utf8).write(to: file)
        store.restoreBoard(from: file)
        XCTAssertEqual(store.saved.projects.first?.name, "Restored")
    }
    func testCorruptCurrentBoardIsPreservedDuringRecovery() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("board.json")
        let original = Data("unreadable-original".utf8); try original.write(to: file)
        let persistence = StatePersistence()
        XCTAssertFalse(persistence.writeSync(SavedState(), to: file))
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertTrue(persistence.restoreSync(SavedState(), to: file))
        let recovery = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Recovery"), includingPropertiesForKeys: nil)
        XCTAssertEqual(recovery.count, 1); XCTAssertEqual(try Data(contentsOf: recovery[0]), original)
        XCTAssertNoThrow(try StatePersistence.decode(Data(contentsOf: file)))
    }
    @MainActor func testDiagnosticsOnlyContainAllowlistedAggregateData() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = BoardStore(root: root, start: false)
        store.saved.cards = [card("private-id")]
        store.saved.projects = [Project(name: "private-project", note: "private-note")]
        store.health = ["codex": "Unavailable · private-secret-error"]
        let report = root.appendingPathComponent("diagnostics.json"); store.exportDiagnostics(to: report)
        let text = try String(contentsOf: report)
        XCTAssertFalse(text.contains("private-")); XCTAssertFalse(text.contains("/private"))
        XCTAssertTrue(text.contains("Unavailable")); XCTAssertTrue(text.contains("captured"))
    }
}
