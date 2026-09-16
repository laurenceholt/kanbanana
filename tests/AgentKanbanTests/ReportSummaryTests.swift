import KanbananaCore
import KanbananaServices
import XCTest
@testable import AgentKanban

private struct ReportCredentials: CredentialStorage {
    func status() async -> CredentialStatus { .saved }
    func load() async throws -> String { "synthetic" }
    func save(_ value: String) async throws { }
}

private actor ReportAPI {
    var inputs: [SummaryInput] = []
    var holdReports = false
    var resume: CheckedContinuation<Void, Never>?
    func hold() { holdReports = true }
    func release() { resume?.resume(); resume = nil }
    func summarize(_ input: SummaryInput) async -> String {
        inputs.append(input)
        if holdReports && input.kind == .agentReport { await withCheckedContinuation { resume = $0 } }
        return (input.kind == .agentReport ? "Report: " : "Request: ") + input.text
    }
}

final class ReportSummaryTests: XCTestCase {
    private func card(state: Column = .ready, response: String = "Added labels; tests were not run.") -> Conversation {
        Conversation(id: "codex:example", provider: "codex", nativeID: "example", title: "Example", folder: "",
            updated: 100, requests: [.init(id: "request", text: "Add labels and run tests", time: 90)],
            state: state, reason: "", response: response, eventID: "delivered", eventTime: 100, url: "")
    }
    @MainActor private func settle(_ store: BoardStore) async {
        for _ in 0..<400 {
            if !store.isSummarizing { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Summary queue did not finish")
    }

    @MainActor func testReportsReplaceCardAsksWithoutChangingHistoryAndSurviveReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let api = ReportAPI()
        let store = await BoardStore.loaded(root: root, start: false, credentials: ReportCredentials(),
            summarize: { input, _, _ in await api.summarize(input) })
        var c = card()
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 100))
        store.setAIEnabled(true)
        await settle(store)
        XCTAssertEqual(store.cardSummary(c), "Report: Added labels; tests were not run.")
        XCTAssertEqual(store.summary(c, c.requests[0]), "Request: Add labels and run tests")
        await store.persist()
        let reloaded = await BoardStore.loaded(root: root, start: false, credentials: ReportCredentials(),
            summarize: { input, _, _ in await api.summarize(input) })
        XCTAssertEqual(reloaded.cardSummary(try XCTUnwrap(reloaded.cards.first)), store.cardSummary(c))
        reloaded.queueSummaries(); await settle(reloaded)
        let calls = await api.inputs.count
        XCTAssertEqual(calls, 2, "Unchanged report and ask must use the persistent cache")

        c.state = .needsMe; c.response = "Which repository should I use?"; c.eventID = "question"
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 101))
        XCTAssertNil(store.cardSummary(c), "Never show a cached summary of a different report")
        await settle(store)
        XCTAssertEqual(store.cardSummary(c), "Report: Which repository should I use?")
        XCTAssertEqual(store.summary(c, c.requests[0]), "Request: Add labels and run tests")

        c.requests.append(.init(id: "next", text: "Use the example repo", time: 102))
        c.state = .running; c.response = ""; c.eventID = "started"; c.eventTime = 102
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 102))
        await settle(store)
        XCTAssertEqual(store.cardSummary(c), "Request: Use the example repo")
        await store.stop(); await reloaded.stop()
    }

    @MainActor func testMissingReportDoesNotMasqueradeAsRequestSummary() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = await BoardStore.loaded(root: root, start: false)
        for column in [Column.ready, .needsMe] {
            let c = card(state: column, response: "  ")
            try await store.installFixture {
                $0.cards = [c]
                $0.summaries[c.id + ":request"] = Summary(text: "Add labels", inputHash: BoardStore.hash(c.requests[0].text))
            }
            XCTAssertNil(store.cardSummary(c))
            XCTAssertNil(c.cardSummaryInput(in: column))
            XCTAssertEqual(store.summary(c, c.requests[0]), "Add labels")
        }
        await store.stop()
    }

    @MainActor func testNewRequestDiscardsInFlightReportSummary() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let api = ReportAPI(); await api.hold()
        let store = await BoardStore.loaded(root: root, start: false, credentials: ReportCredentials(),
            summarize: { input, _, _ in await api.summarize(input) })
        var c = card()
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 100))
        store.setAIEnabled(true)
        for _ in 0..<400 {
            if await api.resume != nil { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let waiting = await api.resume != nil
        XCTAssertTrue(waiting)
        c.state = .running; c.response = ""; c.eventID = "new"
        c.requests.append(.init(id: "next", text: "Now add a legend", time: 101))
        store.apply(.init(cards: [c], health: ["codex": "Connected"], scannedAt: 101))
        await api.release(); await settle(store)
        XCTAssertNil(store.saved.summaries[c.reportSummaryKey])
        XCTAssertNil(store.cardSummary(c))
        await store.stop()
    }

    func testReportUsesReportPromptAndOnlySelectedReportText() async throws {
        let text = "Built it; tests failed. Please choose a target."
        _ = try await GPT.summarize(SummaryInput(text, kind: .agentReport), model: "test", key: "synthetic", transport: { request in
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
            XCTAssertEqual(body["input"] as? String, text)
            XCTAssertEqual(body["instructions"] as? String, SummaryStyle.reportInstructions)
            XCTAssertEqual(body["store"] as? Bool, false)
            return (Data(#"{"output":[{"content":[{"type":"output_text","text":"Built it; tests failed. Needs your target choice."}]}]}"#.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
    }
}
