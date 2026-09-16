import Foundation
import os
import Testing
import KanbananaCore
import KanbananaServices

@Test func framerHandlesChunkBoundariesAndEnforcesPerFrameLimit() throws {
    var framer = ReaderFramer(maximumBytes: 5)
    #expect(try framer.append(Data("abc".utf8)).isEmpty)
    #expect(try framer.append(Data("de\nx\ny\n".utf8)).map { String(decoding: $0, as: UTF8.self) } == ["abcde", "x", "y"])
    try framer.finish()
    #expect(throws: (any Error).self) { try framer.append(Data("123456".utf8)) }
    var unfinished = ReaderFramer()
    _ = try unfinished.append(Data("partial".utf8))
    #expect(throws: (any Error).self) { try unfinished.finish() }
}

@Test func protocolRejectsWrongVersionProviderAndManualState() throws {
    let bytes = try fixtureFrame()
    #expect(throws: (any Error).self) { try JSONDecoder().decode(ReaderFrame.self, from: bytes).snapshot(expected: .codex) }
    for (field, value) in [("protocolVersion", 99 as Any), ("cards", [["state": "todo"]] as Any)] {
        var json = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        json[field] = value
        let changed = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ReaderFrame.self, from: changed).snapshot(expected: .claude) }
    }
}

/// The stream and continuation are immutable; counters live in a separate actor.
private final class TestConnection: ReaderConnection, Sendable {
    let output: AsyncThrowingStream<Data, Error>
    let continuation: AsyncThrowingStream<Data, Error>.Continuation
    let stopped: @Sendable () -> Void
    init(_ initial: Data? = nil, stopped: @escaping @Sendable () -> Void = {}) {
        self.stopped = stopped
        (output, continuation) = AsyncThrowingStream.makeStream()
        if let initial { continuation.yield(initial) }
    }
    func stop() async { continuation.finish(); stopped() }
}

private struct ConnectionCounts: Sendable {
    var active: [String: Set<UUID>] = [:]
    var maximum = 0
    var launches = 0
}

@Test @MainActor func repeatedRetryReapsBeforeReplacement() async throws {
    let probe = OSAllocatedUnfairLock(initialState: ConnectionCounts())
    let source = String(decoding: try fixtureFrame(), as: UTF8.self)
    let supervisor = ReaderSupervisor(deadline: 5, factory: { _, args in
        let provider = args.contains("claude") ? "claude" : "codex"
        let id = UUID()
        probe.withLock {
            $0.active[provider, default: []].insert(id)
            $0.maximum = max($0.maximum, $0.active[provider]!.count)
            $0.launches += 1
        }
        let frame = source.replacingOccurrences(of: "claude", with: provider) + "\n"
        return TestConnection(Data(frame.utf8)) { probe.withLock { _ = $0.active[provider]?.remove(id) } }
    })
    var received = 0
    supervisor.start(config()) { _ in received += 1 }
    try await waitUntil { received >= 2 }
    for _ in 0..<25 { supervisor.start(config()) { _ in received += 1 } }
    try await waitUntil { received >= 4 }
    await supervisor.stop()
    #expect(probe.withLock { $0.maximum } == 1)
    #expect(probe.withLock { $0.active.values.allSatisfy(\.isEmpty) })
    #expect(probe.withLock { $0.launches } == 4)
}

private func config(disabled: Set<String> = []) -> ReaderConfiguration {
    var privacy = PrivacyOptions(); privacy.disabledProviders = disabled
    return ReaderConfiguration(executable: URL(fileURLWithPath: "/unused"), script: URL(fileURLWithPath: "/unused"),
        days: 14, trackedIDs: [], privacy: privacy)
}

@MainActor private func waitUntil(_ predicate: () -> Bool) async throws {
    for _ in 0..<300 {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for a reader event")
}

@Test @MainActor func watchdogContinuesAfterFirstSuccessfulFrame() async throws {
    let frame = try fixtureFrame() + Data([10])
    let connection = TestConnection(frame)
    let supervisor = ReaderSupervisor(deadline: 0.04, factory: { _, _ in connection })
    var observations: [ProviderSnapshot] = []
    supervisor.start(config(disabled: ["codex"])) { observations.append($0) }
    try await waitUntil { observations.contains { $0.health.status == .stale } }
    #expect(observations.contains { $0.provider == .claude && $0.health.status == .connected })
    #expect(observations.contains { $0.provider == .codex && $0.health.status == .disabled })
    await supervisor.stop()
}

@Test @MainActor func oneProviderCanFailWhileOtherKeepsReporting() async throws {
    let first = TestConnection(Data("not-json\n".utf8))
    let second = TestConnection()
    let supervisor = ReaderSupervisor(deadline: 2, factory: { _, args in args.contains("claude") ? first : second })
    var observations: [ProviderSnapshot] = []
    supervisor.start(config()) { observations.append($0) }
    try await waitUntil { observations.contains { $0.provider == .claude && $0.health.status == .unavailable } }
    let heartbeat = #"{"protocolVersion":1,"provider":"codex","cards":[],"health":{"status":"connected"},"inventoryComplete":true,"knownIDs":[],"scannedAt":300}"#
    second.continuation.yield(Data((heartbeat + "\n").utf8))
    try await waitUntil { observations.contains { $0.provider == .codex && $0.health.status == .connected } }
    #expect(!observations.contains { $0.provider == .codex && $0.health.status == .unavailable })
    await supervisor.stop()
}

@Test @MainActor func cancelledHistoryStopsWithoutWaitingForDeadline() async throws {
    let connection = TestConnection()
    let supervisor = ReaderSupervisor(deadline: 60, factory: { _, args in args.contains("--history-id") ? connection : TestConnection() })
    supervisor.start(config()) { _ in }
    let card = try JSONDecoder().decode(ReaderFrame.self, from: fixtureFrame()).snapshot(expected: .claude).cards[0]
    let task = Task { try await supervisor.history(card, before: nil) }
    try await Task.sleep(for: .milliseconds(10))
    task.cancel()
    var completed = false
    let waiter = Task { _ = try? await task.value; completed = true }
    try await waitUntil { completed }
    await supervisor.stop()
    await waiter.value
}

@Test func processStopEscalatesAndReapsStubbornWorker() async throws {
    let connection = ProcessReaderConnection(executable: URL(fileURLWithPath: "/usr/bin/python3"),
        arguments: ["-I", "-u", "-c", "import os,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print(os.getpid(),flush=True); time.sleep(60)"])
    var pid: Int32?
    for try await chunk in connection.output {
        pid = Int32(String(decoding: chunk, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        break
    }
    let child = try #require(pid)
    await connection.stop()
    #expect(kill(child, 0) == -1)
    #expect(errno == ESRCH)
}

@Test func startupBurstWaitsForSlowConsumerWithoutDroppingData() async throws {
    let expected = 4 * 1024 * 1024
    let connection = ProcessReaderConnection(executable: URL(fileURLWithPath: "/usr/bin/python3"),
        arguments: ["-I", "-B", "-u", "-c", "import sys; sys.stdout.buffer.write(b'x' * \(expected)); sys.stdout.flush()"])
    var received = 0
    do {
        // Let the worker fill its pipe before consumption begins, as on startup.
        try await Task.sleep(for: .milliseconds(50))
        for try await chunk in connection.output {
            received += chunk.count
            try await Task.sleep(for: .milliseconds(1))
        }
    } catch {
        await connection.stop()
        throw error
    }
    await connection.stop()
    #expect(received == expected)
}

@Test func stopCanReapWorkerWithoutAnyConsumer() async throws {
    let connection = ProcessReaderConnection(executable: URL(fileURLWithPath: "/usr/bin/python3"),
        arguments: ["-I", "-B", "-u", "-c", "import sys; sys.stdout.buffer.write(b'x' * (16 * 1024 * 1024)); sys.stdout.flush()"])
    try await Task.sleep(for: .milliseconds(50))
    await connection.stop()
    var receivedAfterStop = 0
    for try await chunk in connection.output { receivedAfterStop += chunk.count }
    #expect(receivedAfterStop == 0)
}
