import Combine
import CryptoKit
import Foundation
import KanbananaCore

package enum RequestDigest {
    package static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Owns credential access, one cancellable queue, and cloud side effects. The
/// application supplies a current value snapshot; this service cannot mutate a board.
@MainActor package final class SummaryScheduler: ObservableObject {
    @Published package private(set) var status = "Summaries are off. Your saved key can be reused."
    @Published package private(set) var credentialStatus: CredentialStatus = .checking
    @Published package private(set) var savingKey = false
    @Published package private(set) var isRunning = false
    @Published package private(set) var issue: String?

    private let credentials: any CredentialStorage
    private let repository: any BoardRepository
    private let summarize: @Sendable (SummaryInput, String, String) async throws -> String
    private let state: @MainActor () -> SavedState
    private let received: @MainActor (String, Summary) -> Void
    private let reserved: @MainActor (SummaryUsage) -> Void
    private let clock: ServiceClock
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var cachedKey: String?
    private var skipped: [String: String] = [:]

    package init(credentials: any CredentialStorage, repository: any BoardRepository,
                 clock: ServiceClock = ServiceClock(),
                 summarize: @escaping @Sendable (SummaryInput, String, String) async throws -> String,
                 state: @escaping @MainActor () -> SavedState,
                 received: @escaping @MainActor (String, Summary) -> Void,
                 reserved: @escaping @MainActor (SummaryUsage) -> Void) {
        self.credentials = credentials
        self.repository = repository
        self.clock = clock
        self.summarize = summarize
        self.state = state
        self.received = received
        self.reserved = reserved
    }

    package static func allowed(_ card: Conversation, in state: SavedState) -> Bool {
        let privacy = state.privacy ?? PrivacyOptions()
        return !privacy.disabledProviders.contains(card.provider)
            && !privacy.excludedSummaryProjects.contains(state.dispositions[card.id]?.projectID ?? "")
    }
    package func cancel(clearIssue: Bool = false) {
        task?.cancel()
        task = nil
        generation = UUID()
        isRunning = false
        if clearIssue { issue = nil }
    }
    package func settingsChanged() {
        cancel(clearIssue: true)
        skipped.removeAll()
        status = state().aiEnabled ? "Preparing summaries…" : "Summaries are off. Your saved key can be reused."
        queue()
    }
    package func retry() {
        if credentialStatus == .accessNeeded { cachedKey = nil }
        settingsChanged()
    }
    package func refreshKeyStatus() async {
        let result = await credentials.status()
        if !savingKey { credentialStatus = cachedKey == nil ? result : .saved }
    }
    package func saveKey(_ text: String) async -> Bool {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !savingKey else { return false }
        cancel(clearIssue: true)
        savingKey = true
        defer { savingKey = false }
        do {
            try await credentials.save(key)
            cachedKey = key
            credentialStatus = .saved
            skipped.removeAll()
            status = "Key saved. Ready to summarize."
            savingKey = false
            queue()
            return true
        } catch {
            issue = error.localizedDescription
            status = "Key was not saved. " + error.localizedDescription
            return false
        }
    }
    package func deleteKey() async {
        guard !savingKey else { return }
        cancel(clearIssue: true)
        savingKey = true
        defer { savingKey = false }
        do {
            try await credentials.delete()
            cachedKey = nil
            credentialStatus = .missing
            status = "Key deleted. Summaries are off."
        } catch {
            issue = error.localizedDescription
            status = "Could not delete the key. " + error.localizedDescription
        }
    }

    private struct Job {
        let cardID: String
        let input: SummaryInput
        let requestID: String?
        let reportRevision: String?
        var id: String { requestID.map { cardID + ":" + $0 } ?? "agent-report:" + cardID }
        init(cardID: String, request: RequestItem) {
            self.cardID = cardID; input = SummaryInput(request.text)
            requestID = request.id; reportRevision = nil
        }
        init?(report card: Conversation, column: Column) {
            guard let input = card.cardSummaryInput(in: column), input.kind == .agentReport else { return nil }
            cardID = card.id; self.input = input; requestID = nil; reportRevision = card.revision
        }
    }
    private func pending(_ job: Job, state: SavedState) -> Bool {
        guard let card = state.cards.first(where: { $0.id == job.cardID }), Self.allowed(card, in: state) else { return false }
        if let requestID = job.requestID {
            guard card.requests.contains(where: { $0.id == requestID && $0.text == job.input.text }) else { return false }
        } else {
            let column = Lifecycle.column(card, state.dispositions[card.id] ?? Disposition())
            guard card.revision == job.reportRevision, card.cardSummaryInput(in: column) == job.input else { return false }
        }
        let hash = RequestDigest.hash(job.input.text)
        guard skipped[job.id] != hash else { return false }
        guard let summary = state.summaries[job.id] else { return true }
        return summary.inputHash != hash || (job.input.kind == .agentReport
            ? summary.styleVersion != SummaryStyle.version : SummaryStyle.needsRefresh(summary))
    }
    package func queue(history cardID: String? = nil) {
        let current = state()
        guard current.aiEnabled, task == nil, !savingKey, issue == nil else { return }
        let cards = current.cards.sorted { $0.updated > $1.updated }
        var jobs: [Job]
        if let cardID {
            jobs = (cards.first { $0.id == cardID }?.requests.reversed() ?? []).map { Job(cardID: cardID, request: $0) }
        } else {
            jobs = cards.compactMap { card in
                Job(report: card, column: Lifecycle.column(card, current.dispositions[card.id] ?? Disposition()))
            }
            // Reports currently visible on cards take priority; request summaries
            // remain independent so the history log continues to describe asks.
            jobs += cards.compactMap { card in card.requests.last.map { Job(cardID: card.id, request: $0) } }
            for card in cards {
                jobs += card.requests.dropLast().reversed().compactMap { request in
                    let job = Job(cardID: card.id, request: request)
                    guard let cached = current.summaries[job.id], SummaryStyle.needsRefresh(cached),
                          cached.inputHash == RequestDigest.hash(request.text) else { return nil }
                    return job
                }
            }
        }
        jobs = jobs.filter { pending($0, state: current) }
        guard !jobs.isEmpty else {
            status = skipped.isEmpty ? "Card summaries up to date." : "Summaries up to date; \(skipped.count) items kept as excerpts. Retry to try them again."
            return
        }
        let token = UUID()
        generation = token
        let model = current.model
        isRunning = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == token { self.task = nil; self.isRunning = false } }
            do {
                let key: String
                if let cachedKey = self.cachedKey { key = cachedKey }
                else {
                    self.status = "Reading saved key from Keychain…"
                    key = try await self.credentials.load()
                    guard !Task.isCancelled, self.generation == token else { return }
                    self.cachedKey = key
                    self.credentialStatus = .saved
                }
                for job in jobs {
                    guard !Task.isCancelled, self.generation == token, self.state().aiEnabled else { return }
                    guard self.pending(job, state: self.state()) else { continue }
                    let limit = self.state().privacy?.dailySummaryLimit ?? 100
                    let usage = try await self.repository.reserveSummary(limit: limit, day: SummaryUsage.today(self.clock.now()))
                    self.reserved(usage)
                    guard !Task.isCancelled, self.generation == token, self.state().aiEnabled,
                          self.pending(job, state: self.state()) else { return }
                    self.status = cardID == nil ? "Summarizing cards…" : "Summarizing request history…"
                    do {
                        let text = try await self.summarize(job.input, model, key)
                        guard !Task.isCancelled, self.generation == token, self.state().aiEnabled else { return }
                        // Reject edited asks, superseded reports and newly excluded projects.
                        guard self.pending(job, state: self.state()) else { continue }
                        self.received(job.id, Summary(text: text, inputHash: RequestDigest.hash(job.input.text), styleVersion: SummaryStyle.version))
                    } catch let error as GPT.Failure where error.requestOnly {
                        self.skipped[job.id] = RequestDigest.hash(job.input.text)
                    }
                }
                self.status = "Card summaries up to date."
            } catch {
                guard !Task.isCancelled, self.generation == token else { return }
                if let error = error as? Keychain.Failure { self.credentialStatus = error.isMissing ? .missing : .accessNeeded }
                // The daily cap resumes automatically; API/credential failures require Retry.
                if case RepositoryFailure.dailyLimit = error { self.status = error.localizedDescription }
                else { self.issue = error.localizedDescription; self.status = "Summaries paused. " + error.localizedDescription }
            }
        }
    }
}
