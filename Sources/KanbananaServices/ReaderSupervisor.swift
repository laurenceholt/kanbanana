import Foundation
import KanbananaCore

package struct ServiceClock: Sendable {
    package var now: @Sendable () -> Date
    package var sleep: @Sendable (Double) async throws -> Void
    package init(now: @escaping @Sendable () -> Date = { Date() },
                 sleep: @escaping @Sendable (Double) async throws -> Void = {
                     try await Task.sleep(nanoseconds: UInt64(max(0, $0) * 1_000_000_000))
                 }) {
        self.now = now
        self.sleep = sleep
    }
}

@MainActor package protocol SessionMonitoring: AnyObject {
    func start(_ configuration: ReaderConfiguration, receive: @escaping @MainActor @Sendable (ProviderSnapshot) -> Void)
    func stop() async
    func history(_ card: Conversation, before: String?) async throws -> HistoryPage
}

/// Each provider has its own lifecycle and freshness deadline. Restart waits for
/// the previous connection to terminate, including rapid Retry/configuration changes.
@MainActor package final class ReaderSupervisor: SessionMonitoring {
    package typealias Factory = @Sendable (URL, [String]) -> any ReaderConnection
    private let factory: Factory
    private let clock: ServiceClock
    private let deadline: Double
    private var configuration: ReaderConfiguration?
    private var generation = UUID()
    private var tasks: [ProviderID: Task<Void, Never>] = [:]
    private var lastResponse: [ProviderID: Date] = [:]
    private var connections: [ProviderID: any ReaderConnection] = [:]
    private var replacement: Task<Void, Never>?
    private var historyConnections: [UUID: any ReaderConnection] = [:]

    package init(deadline: Double = 20, clock: ServiceClock = ServiceClock(),
                 factory: @escaping Factory = { ProcessReaderConnection(executable: $0, arguments: $1) }) {
        self.deadline = deadline
        self.clock = clock
        self.factory = factory
    }

    package func start(_ configuration: ReaderConfiguration, receive: @escaping @MainActor @Sendable (ProviderSnapshot) -> Void) {
        generation = UUID()
        let token = generation
        self.configuration = configuration
        for task in tasks.values { task.cancel() }
        let preceding = replacement
        let oldTasks = Array(tasks.values)
        let oldConnections = Array(connections.values) + Array(historyConnections.values)
        historyConnections.removeAll()
        tasks.removeAll()
        connections.removeAll()
        replacement = Task {
            await preceding?.value
            for connection in oldConnections { await connection.stop() }
            for task in oldTasks { await task.value }
            guard generation == token, !Task.isCancelled else { return }
            for provider in ProviderID.allCases {
                if configuration.privacy.disabledProviders.contains(provider.rawValue) {
                    receive(ProviderSnapshot(provider: provider, cards: [], health: ProviderHealth(.disabled),
                        inventoryComplete: false, knownIDs: [], scannedAt: clock.now().timeIntervalSince1970))
                } else {
                    tasks[provider] = Task { [weak self] in
                        await self?.run(provider, configuration: configuration, token: token, receive: receive)
                    }
                }
            }
        }
    }

    private func run(_ provider: ProviderID, configuration: ReaderConfiguration, token: UUID,
                     receive: @escaping @MainActor @Sendable (ProviderSnapshot) -> Void) async {
        var failures = 0
        var tracked = Set(configuration.trackedIDs)
        while !Task.isCancelled && generation == token {
            var current = configuration
            current.trackedIDs = Array(tracked)
            let connection = factory(current.executable, current.arguments(for: provider))
            connections[provider] = connection
            lastResponse[provider] = clock.now()
            var timedOut = false
            let watchdog = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled && self.generation == token {
                    do { try await self.clock.sleep(min(1, self.deadline / 2)) } catch { return }
                    guard !Task.isCancelled, self.generation == token else { return }
                    let elapsed = self.clock.now().timeIntervalSince(self.lastResponse[provider] ?? self.clock.now())
                    // A backwards wall-clock adjustment invalidates freshness too.
                    if elapsed > self.deadline || elapsed < -1 {
                        timedOut = true
                        receive(self.failure(provider, .stale, "Reader timed out; reconnecting"))
                        await connection.stop()
                        return
                    }
                }
            }
            do {
                var framer = ReaderFramer()
                for try await chunk in connection.output {
                    guard !Task.isCancelled, generation == token else { break }
                    for data in try framer.append(chunk) {
                        let frame = try JSONDecoder().decode(ReaderFrame.self, from: data)
                        let snapshot = try frame.snapshot(expected: provider)
                        lastResponse[provider] = clock.now()
                        failures = 0
                        tracked.formUnion(snapshot.knownIDs)
                        tracked.formUnion(snapshot.cards.map(\.id))
                        receive(snapshot)
                    }
                }
                try framer.finish()
                if !Task.isCancelled && generation == token && !timedOut {
                    receive(failure(provider, .unavailable, "Reader stopped; reconnecting"))
                }
            } catch {
                if !Task.isCancelled && generation == token && !timedOut {
                    let issue = (error as? ReaderFailure)?.errorDescription ?? "Reader could not decode a source update"
                    receive(failure(provider, .unavailable, issue))
                }
            }
            watchdog.cancel()
            await watchdog.value
            await connection.stop()
            if generation == token { connections[provider] = nil }
            failures += 1
            do { try await clock.sleep(min(30, pow(2, Double(min(failures, 5))))) } catch { return }
        }
    }

    private func failure(_ provider: ProviderID, _ status: ProviderHealth.Status, _ issue: String?) -> ProviderSnapshot {
        ProviderSnapshot(provider: provider, cards: [], health: ProviderHealth(status, issue: issue),
                         inventoryComplete: false, knownIDs: [], scannedAt: clock.now().timeIntervalSince1970)
    }

    package func stop() async {
        generation = UUID()
        let oldTasks = Array(tasks.values)
        let oldConnections = Array(connections.values) + Array(historyConnections.values)
        historyConnections.removeAll()
        for task in oldTasks { task.cancel() }
        await replacement?.value
        for connection in oldConnections { await connection.stop() }
        for task in oldTasks { await task.value }
        tasks.removeAll()
        connections.removeAll()
    }

    package func history(_ card: Conversation, before: String?) async throws -> HistoryPage {
        guard let configuration, let provider = ProviderID(rawValue: card.provider),
              !configuration.privacy.disabledProviders.contains(card.provider) else { throw ReaderFailure.missing }
        let token = generation
        let id = UUID()
        let connection = factory(configuration.executable, configuration.arguments(for: provider, historyID: card.id, before: before))
        historyConnections[id] = connection
        var timedOut = false
        let timeout = Task {
            do { try await clock.sleep(deadline) } catch { return }
            guard !Task.isCancelled else { return }
            timedOut = true
            await connection.stop()
        }
        defer { timeout.cancel(); historyConnections[id] = nil }
        return try await withTaskCancellationHandler {
            do {
                var framer = ReaderFramer()
                var page: HistoryPage?
                for try await chunk in connection.output {
                    try Task.checkCancellation()
                    guard generation == token else { throw CancellationError() }
                    for data in try framer.append(chunk) {
                        guard page == nil else { throw ReaderFailure.malformed }
                        let next = try JSONDecoder().decode(HistoryPage.self, from: data)
                        guard next.protocolVersion == 1, next.cardID == card.id,
                              next.requests.count <= 50, next.requests.allSatisfy({ $0.time.isFinite }),
                              Set(next.requests.map(\.id)).count == next.requests.count else { throw ReaderFailure.malformed }
                        page = next
                    }
                }
                try framer.finish()
                await connection.stop()
                try Task.checkCancellation()
                guard generation == token else { throw CancellationError() }
                guard !timedOut, let page else { throw ReaderFailure.stopped }
                return page
            } catch {
                await connection.stop()
                throw error
            }
        } onCancel: {
            Task { await connection.stop() }
        }
    }
}
