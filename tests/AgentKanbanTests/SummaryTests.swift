import KanbananaCore
import KanbananaServices
import XCTest
@testable import AgentKanban

private actor ResponsesStub {
    var responses: [(Int, String)]
    var bodies: [Data] = []
    init(_ responses: [(Int, String)]) { self.responses = responses }
    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        bodies.append(request.httpBody ?? Data())
        let next = responses.removeFirst()
        return (Data(next.1.utf8), HTTPURLResponse(url: request.url!, statusCode: next.0, httpVersion: nil, headerFields: nil)!)
    }
}

private actor MemoryCredentials: CredentialStorage {
    var key: String?
    var failSave = false
    init(_ key: String?) { self.key = key }
    func status() -> CredentialStatus { key == nil ? .missing : .saved }
    func load() throws -> String { guard let key else { throw Keychain.Failure(status: -25300) }; return key }
    func save(_ value: String) throws {
        if failSave { throw Keychain.Failure(status: -25293) }
        key = value
    }
    func rejectSaves() { failSave = true }
}

private actor SummaryStub {
    var calls = 0
    var failAPI = false
    func setAPIError(_ value: Bool) { failAPI = value }
    func summarize(_ text: String) throws -> String {
        calls += 1
        if failAPI { throw GPT.Failure.api(401) }
        if text.count > 30000 { throw GPT.Failure.tooLong }
        return "Fix the labels."
    }
}

final class SummaryTests: XCTestCase {
    func testIncompleteResponseRetriesWithoutSavingPartialText() async throws {
        let api = ResponsesStub([
            (200, #"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[{"content":[{"type":"output_text","text":"truncated"}]}]}"#),
            (200, #"{"status":"completed","output":[{"type":"reasoning"},{"content":[{"type":"output_text","text":"Fix the labels."}]}]}"#)
        ])
        let result = try await GPT.summarize("Fix labels", model: "gpt-5.6-luna", key: "test-only", transport: { try await api.send($0) })
        XCTAssertEqual(result, "Fix the labels.")
        let bodies = await api.bodies
        let first = try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[0]) as? [String: Any])
        let retry = try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[1]) as? [String: Any])
        XCTAssertGreaterThan(retry["max_output_tokens"] as! Int, first["max_output_tokens"] as! Int)
        XCTAssertEqual(first["model"] as? String, "gpt-5.6-luna")
        XCTAssertEqual(first["store"] as? Bool, false)
        XCTAssertEqual((first["reasoning"] as? [String: String])?["effort"], "none")
    }
    func testEmptyOutputRetriesOnlyOnce() async throws {
        let api = ResponsesStub([(200, #"{"status":"completed","output":[]}"#), (200, #"{"status":"completed","output":[]}"#)])
        do {
            _ = try await GPT.summarize("Fix labels", model: "gpt-5.6-luna", key: "test-only", transport: { try await api.send($0) })
            XCTFail("Expected an empty-response error")
        } catch { XCTAssertEqual(error as? GPT.Failure, .empty) }
        let count = await api.bodies.count
        XCTAssertEqual(count, 2)
    }
    func testAuthenticationFailureDoesNotRetryOrExposeResponseBody() async throws {
        let api = ResponsesStub([(401, #"{"error":{"message":"untrusted server text"}}"#)])
        do {
            _ = try await GPT.summarize("Fix labels", model: "gpt-5.6-luna", key: "test-only", transport: { try await api.send($0) })
            XCTFail("Expected authentication failure")
        } catch {
            XCTAssertEqual(error as? GPT.Failure, .api(401))
            XCTAssertFalse(error.localizedDescription.contains("untrusted server text"))
        }
        let count = await api.bodies.count
        XCTAssertEqual(count, 1)
    }
    @MainActor func testSavedKeySurvivesStoreReloadAndFailedReplacement() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let credentials = MemoryCredentials(nil)
        let store = await BoardStore.loaded(root: root, start: false, credentials: credentials)
        let saved = await store.saveKey("  test-only-key\n")
        XCTAssertTrue(saved)
        await store.persist()
        XCTAssertFalse(try String(contentsOf: store.dataFile).contains("test-only-key"))
        let reloaded = await BoardStore.loaded(root: root, start: false, credentials: credentials)
        await reloaded.refreshKeyStatus()
        XCTAssertEqual(reloaded.credentialStatus, .saved)
        await credentials.rejectSaves()
        let replaced = await reloaded.saveKey("replacement")
        XCTAssertFalse(replaced)
        let key = try await credentials.load()
        XCTAssertEqual(key, "test-only-key")
        let blank = await reloaded.saveKey(" \n ")
        XCTAssertFalse(blank)
    }
    @MainActor func testAPIFailurePreservesEnabledPreferenceAndRetriesExistingKey() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let credentials = MemoryCredentials("test-only")
        let api = SummaryStub(); await api.setAPIError(true)
        let store = await BoardStore.loaded(root: root, start: false, credentials: credentials, summarize: { text, _, _ in try await api.summarize(text.text) })
        try await store.installFixture { state in state.cards = [card("a", "Fix labels")] }
        store.setAIEnabled(true)
        await settle(store)
        XCTAssertTrue(store.saved.aiEnabled)
        XCTAssertNotNil(store.summaryIssue)
        for _ in 0..<10 { store.queueSummaries() }
        let calls = await api.calls
        XCTAssertEqual(calls, 1)
        await api.setAPIError(false)
        store.retrySummaries()
        await settle(store)
        XCTAssertNil(store.summaryIssue)
        XCTAssertEqual(store.saved.summaries.count, 1)
        XCTAssertEqual(store.credentialStatus, .saved)
    }
    @MainActor func testOneOversizedRequestDoesNotStopOtherSummaries() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let api = SummaryStub()
        let store = await BoardStore.loaded(root: root, start: false, credentials: MemoryCredentials("test-only"), summarize: { text, _, _ in try await api.summarize(text.text) })
        try await store.installFixture { state in state.cards = [card("a", String(repeating: "x", count: 30001)), card("b", "Fix labels")] }
        store.setAIEnabled(true)
        await settle(store)
        XCTAssertTrue(store.saved.aiEnabled)
        XCTAssertNil(store.summaryIssue)
        XCTAssertEqual(store.saved.summaries.count, 1)
        store.queueSummaries()
        let calls = await api.calls
        XCTAssertEqual(calls, 2)
    }
    @MainActor func testVoiceRefreshPreservesHistoryAndDoesNotGenerateUnrequestedSummaries() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let api = SummaryStub()
        let credentials = MemoryCredentials("test-only")
        let store = await BoardStore.loaded(root: root, start: false, credentials: credentials, summarize: { text, _, _ in try await api.summarize(text.text) })
        var conversation = card("a", "Fix labels")
        let oldRequest = RequestItem(id: "old", text: "Proceed", time: 0)
        let untouched = RequestItem(id: "unrequested", text: "An older request", time: 0)
        let personal = RequestItem(id: "personal", text: "Explain my account error", time: 0)
        conversation.requests = [untouched, oldRequest, personal] + conversation.requests
        try await store.installFixture { state in state.cards = [conversation] }
        var legacy = try JSONDecoder().decode(Summary.self, from: Data(#"{"text":"The user asks to proceed.","inputHash":"placeholder"}"#.utf8))
        legacy.inputHash = BoardStore.hash(oldRequest.text)
        let latest = Summary(text: "Fix labels.", inputHash: BoardStore.hash("Fix labels"))
        try await store.installFixture { state in state.summaries = ["a:old": legacy, "a:r": latest, "a:personal": Summary(text: "Explain an error affecting the user.", inputHash: BoardStore.hash(personal.text))] }
        XCTAssertNil(legacy.styleVersion)
        XCTAssertEqual(store.summary(conversation, oldRequest), legacy.text)

        store.setAIEnabled(true)
        await settle(store)
        XCTAssertEqual(store.saved.summaries["a:old"]?.styleVersion, SummaryStyle.version)
        XCTAssertEqual(store.saved.summaries["a:personal"]?.styleVersion, SummaryStyle.version)
        XCTAssertEqual(store.saved.summaries["a:r"], latest)
        XCTAssertNil(store.saved.summaries["a:unrequested"])
        XCTAssertEqual(store.saved.cards, [conversation])
        await store.persist()
        let reloaded = await BoardStore.loaded(root: root, start: false, credentials: credentials, summarize: { text, _, _ in try await api.summarize(text.text) })
        reloaded.queueSummaries()
        await settle(reloaded)
        let count = await api.calls
        XCTAssertEqual(count, 2, "A saved voice refresh must not run again after relaunch")
    }
    @MainActor func testFailedVoiceRefreshKeepsTheExistingSummaryAndCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let api = SummaryStub(); await api.setAPIError(true)
        let store = await BoardStore.loaded(root: root, start: false, credentials: MemoryCredentials("test-only"), summarize: { text, _, _ in try await api.summarize(text.text) })
        let conversation = card("a", "Proceed")
        let old = Summary(text: "The user asks to proceed.", inputHash: BoardStore.hash("Proceed"))
        try await store.installFixture { state in state.cards = [conversation] }; try await store.installFixture { state in state.summaries["a:r"] = old }
        store.setAIEnabled(true)
        await settle(store)
        XCTAssertEqual(store.saved.summaries["a:r"], old)
        XCTAssertEqual(store.summary(conversation, conversation.requests[0]), old.text)
        await api.setAPIError(false)
        store.retrySummaries()
        await settle(store)
        XCTAssertEqual(store.saved.summaries["a:r"]?.styleVersion, SummaryStyle.version)
    }
    private func card(_ id: String, _ text: String) -> Conversation {
        Conversation(id: id, provider: "codex", nativeID: id, title: "Test", folder: "", updated: 1,
            requests: [RequestItem(id: "r", text: text, time: 1)], state: .ready, reason: "", response: "", eventID: "1", eventTime: 1, url: "")
    }
    @MainActor private func settle(_ store: BoardStore) async {
        let deadline = Date().addingTimeInterval(2)
        while store.isSummarizing && Date() < deadline { try? await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertFalse(store.isSummarizing)
    }
}
