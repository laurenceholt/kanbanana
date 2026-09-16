import Foundation
import Testing
import KanbananaCore
@testable import KanbananaServices

func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("kanbanana-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

func fixtureFrame() throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: "provider-frame-v1", withExtension: "json", subdirectory: "Fixtures")!)
}

@Test func wireObservationSurvivesReconciliationAndRepositoryRestart() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let snapshot = try JSONDecoder().decode(ReaderFrame.self, from: fixtureFrame()).snapshot(expected: .claude)
    let repository = FileBoardRepository(root: root)
    let loaded = try await repository.load()
    var state = BoardReconciler.apply(snapshot, to: loaded.state)
    state.projects[0].note = "Our next milestone"
    state.apply(.todoNote("claude:fixture", "Check touch input"), now: 200)
    try await repository.save(state, epoch: loaded.epoch, revision: 1)
    let restarted = try await FileBoardRepository(root: root).load()
    #expect(restarted.state == state)
    let board = try String(contentsOf: root.appendingPathComponent("board.json"), encoding: .utf8)
    #expect(!board.contains("Add labels"))
    #expect(board.contains("Our next milestone"))
}

@Test func legacyMigrationBacksUpBeforeSplittingData() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var legacy = SavedState()
    legacy.projects = [Project(id: "p", name: "Synthetic", note: "Keep me")]
    legacy.summaryUsage = SummaryUsage(day: "2026-09-15", attempts: 7)
    let original = try BoardArchive.data(legacy)
    try original.write(to: root.appendingPathComponent("board.json"))
    let loaded = try await FileBoardRepository(root: root).load()
    #expect(loaded.state == legacy)
    let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
    #expect(backups.count == 1)
    #expect(try Data(contentsOf: backups[0]) == original)
    let header = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("board.json"))) as! [String: Any]
    #expect(header["version"] as? Int == 2)
}

@Test(arguments: [false, true]) func damagedOrInterruptedCachePreservesNotes(mismatchedGeneration: Bool) async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let repository = FileBoardRepository(root: root)
    let loaded = try await repository.load()
    var state = loaded.state
    state.projects = [Project(id: "p", name: "Synthetic", note: "Keep this note")]
    state.dispositions["claude:fixture"] = Disposition(projectID: "p", assignmentLocked: true, todoNote: "Keep this reminder", priority: true)
    try await repository.save(state, epoch: loaded.epoch, revision: 1)
    let cache = root.appendingPathComponent("observations.json")
    if mismatchedGeneration {
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: cache)) as! [String: Any]
        json["generation"] = UUID().uuidString
        try JSONSerialization.data(withJSONObject: json).write(to: cache)
    } else { try Data("broken".utf8).write(to: cache) }
    let recovered = try await FileBoardRepository(root: root).load()
    #expect(recovered.warning != nil)
    #expect(recovered.state.projects == state.projects)
    #expect(recovered.state.dispositions == state.dispositions)
    #expect(recovered.state.cards.isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Recovery").path).count == 1)
}

@Test func futureDocumentIsNeverOverwritten() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let bytes = Data(#"{"version":999,"unknown":"preserve me"}"#.utf8)
    let board = root.appendingPathComponent("board.json"); try bytes.write(to: board)
    let repository = FileBoardRepository(root: root)
    await #expect(throws: (any Error).self) { try await repository.load() }
    await #expect(throws: (any Error).self) { try await repository.save(SavedState(), epoch: UUID(), revision: 1) }
    #expect(try Data(contentsOf: board) == bytes)
}

@Test func restoreInvalidatesQueuedSavesAndPreservesUsage() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let repository = FileBoardRepository(root: root)
    let before = try await repository.load()
    _ = try await repository.reserveSummary(limit: 10, day: "2026-09-15")
    var imported = SavedState(); imported.projects = [Project(name: "Imported")]
    let source = root.appendingPathComponent("export.json"); try BoardArchive.data(imported).write(to: source)
    let restored = try await repository.restore(from: source)
    try await repository.save(before.state, epoch: before.epoch, revision: 999)
    let restarted = try await FileBoardRepository(root: root).load()
    #expect(restarted.state.projects == imported.projects)
    #expect(restored.epoch != before.epoch)
    #expect(restarted.state.summaryUsage?.attempts == 1)
}

@Test func quotaIsDurableAndRollsOverAtNextDay() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let first = FileBoardRepository(root: root); _ = try await first.load()
    _ = try await first.reserveSummary(limit: 1, day: "2026-09-15")
    let restarted = FileBoardRepository(root: root); _ = try await restarted.load()
    await #expect(throws: (any Error).self) { try await restarted.reserveSummary(limit: 1, day: "2026-09-15") }
    #expect(try await restarted.reserveSummary(limit: 1, day: "2026-09-16").attempts == 1)
}

@Test func recoveryOfBrokenBoardCannotResetLedger() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let first = FileBoardRepository(root: root); _ = try await first.load()
    _ = try await first.reserveSummary(limit: 1, day: "2026-09-15")
    try Data("broken".utf8).write(to: root.appendingPathComponent("board.json"))
    let restarted = FileBoardRepository(root: root)
    await #expect(throws: (any Error).self) { try await restarted.load() }
    let source = root.appendingPathComponent("export.json"); try BoardArchive.data(SavedState()).write(to: source)
    _ = try await restarted.restore(from: source)
    await #expect(throws: (any Error).self) { try await restarted.reserveSummary(limit: 1, day: "2026-09-15") }
}

@Test func unreadableLedgerFailsClosedWithoutHidingBoard() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    try Data("broken".utf8).write(to: root.appendingPathComponent("summary-usage.json"))
    let repository = FileBoardRepository(root: root)
    let loaded = try await repository.load()
    #expect(loaded.warning != nil)
    #expect(!loaded.state.aiEnabled)
    await #expect(throws: (any Error).self) { try await repository.reserveSummary(limit: 100, day: "2026-09-15") }
}
