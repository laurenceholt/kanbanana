import Foundation
import Testing
import KanbananaCore
import KanbananaServices

private actor GatedRepository: BoardRepository {
    var waiting = false
    var resume: CheckedContinuation<Void, Never>?
    func load() async throws -> RepositorySnapshot { throw RepositoryFailure.invalid }
    func save(_ state: SavedState, epoch: UUID, revision: UInt64) async throws { }
    func reserveSummary(limit: Int, day: String) async throws -> SummaryUsage {
        waiting = true
        await withCheckedContinuation { resume = $0 }
        return SummaryUsage(day: day, attempts: 1)
    }
    func release() { resume?.resume(); resume = nil }
    func restore(from: URL) async throws -> RepositorySnapshot { throw RepositoryFailure.invalid }
    func export(_ state: SavedState, to: URL) async throws { }
}

private struct SyntheticCredentials: CredentialStorage {
    func status() async -> CredentialStatus { .saved }
    func load() async throws -> String { "synthetic-key" }
    func save(_ value: String) async throws { }
}

private actor APICalls {
    var count = 0
    func summarize() -> String { count += 1; return "Synthetic summary" }
}

@Test @MainActor func exclusionWhileReservingQuotaPreventsNetworkCall() async throws {
    let repository = GatedRepository(), api = APICalls()
    var state = BoardReconciler.apply(try JSONDecoder().decode(ReaderFrame.self, from: fixtureFrame()).snapshot(expected: .claude), to: SavedState())
    state.aiEnabled = true
    var results: [String] = []
    let scheduler = SummaryScheduler(credentials: SyntheticCredentials(), repository: repository,
        summarize: { _, _, _ in await api.summarize() }, state: { state },
        received: { id, _ in results.append(id) }, reserved: { _ in })
    scheduler.queue()
    for _ in 0..<100 {
        if await repository.waiting { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(await repository.waiting)
    var privacy = PrivacyOptions()
    privacy.excludedSummaryProjects = [state.projects[0].id]
    state.privacy = privacy
    await repository.release()
    for _ in 0..<100 {
        if !scheduler.isRunning { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(!scheduler.isRunning)
    #expect(await api.count == 0)
    #expect(results.isEmpty)
}
