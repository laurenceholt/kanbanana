import Foundation
import KanbananaCore

package struct RepositorySnapshot: Sendable {
    package var state: SavedState
    package var epoch: UUID
    package var warning: String?
    package init(state: SavedState, epoch: UUID, warning: String? = nil) {
        self.state = state
        self.epoch = epoch
        self.warning = warning
    }
}

package protocol BoardRepository: Sendable {
    func load() async throws -> RepositorySnapshot
    func save(_ state: SavedState, epoch: UUID, revision: UInt64) async throws
    func reserveSummary(limit: Int, day: String) async throws -> SummaryUsage
    func restore(from source: URL) async throws -> RepositorySnapshot
    func export(_ state: SavedState, to destination: URL) async throws
}

package enum RepositoryFailure: Error, LocalizedError {
    case futureVersion, invalid, dailyLimit, usageUnavailable
    package var errorDescription: String? {
        switch self {
        case .futureVersion: "This board was saved by a newer kanbanana. Its files have been preserved."
        case .invalid: "The board could not be read. Its files have been preserved for recovery."
        case .dailyLimit: "Daily summary limit reached. Summaries resume tomorrow."
        case .usageUnavailable: "Cannot save summary usage. Summaries are paused to preserve the daily limit."
        }
    }
}

/// Portable, complete exports keep the v1 format readable by earlier releases.
/// Installed v2 documents are deliberately smaller and do not contain history.
package enum BoardArchive {
    package static func decode(_ data: Data) throws -> SavedState {
        let state = try JSONDecoder().decode(SavedState.self, from: data)
        guard state.version == 1 else { throw RepositoryFailure.futureVersion }
        try validate(state)
        return state
    }
    package static func validate(_ state: SavedState) throws {
        guard Set(state.cards.map(\.id)).count == state.cards.count,
              Set(state.projects.map(\.id)).count == state.projects.count,
              (1...1000).contains(state.privacy?.dailySummaryLimit ?? 100),
              (state.summaryUsage?.attempts ?? 0) >= 0 else { throw RepositoryFailure.invalid }
        for card in state.cards {
            guard card.updated.isFinite, card.eventTime.isFinite,
                  Set(card.requests.map(\.id)).count == card.requests.count,
                  card.requests.allSatisfy({ $0.time.isFinite }) else { throw RepositoryFailure.invalid }
        }
    }
    package static func data(_ state: SavedState) throws -> Data {
        try validate(state)
        var durable = state
        for i in durable.cards.indices { durable.cards[i].response = "" }
        return try encode(durable)
    }
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    static func write(_ data: Data, to url: URL) throws {
        // Atomic replacement inherits these private permissions on the final file.
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

private struct BoardDocument: Codable {
    var version = 2
    var cacheGeneration: UUID
    var projects: [Project]
    var dispositions: [String: Disposition]
    var model: String
    var aiEnabled: Bool
    var privacy: PrivacyOptions?
    var onboardingComplete: Bool?

    init(_ state: SavedState, generation: UUID) {
        cacheGeneration = generation
        projects = state.projects
        dispositions = state.dispositions
        model = state.model
        aiEnabled = state.aiEnabled
        privacy = state.privacy
        onboardingComplete = state.onboardingComplete
    }
    var state: SavedState {
        var state = SavedState()
        state.projects = projects
        state.dispositions = dispositions
        state.model = model
        state.aiEnabled = aiEnabled
        state.privacy = privacy
        state.onboardingComplete = onboardingComplete
        return state
    }
}

private struct ObservationCache: Codable {
    var version = 1
    var generation: UUID
    var cards: [Conversation]
    var summaries: [String: Summary]

    init(_ state: SavedState, generation: UUID) {
        self.generation = generation
        cards = state.cards.map { original in
            var card = original
            card.response = ""
            card.requests = Array(card.requests.suffix(100))
            return card
        }
        let keys = Set(cards.flatMap { card in card.requests.map { card.id + ":" + $0.id } })
        summaries = state.summaries.filter { keys.contains($0.key) }
    }
}

/// One actor owns all disk writes. No synchronous dispatch back to the main actor.
/// A restore rotates epoch; any previously enqueued save is then harmless.
package actor FileBoardRepository: BoardRepository {
    package let root: URL
    private var boardURL: URL { root.appendingPathComponent("board.json") }
    private var cacheURL: URL { root.appendingPathComponent("observations.json") }
    private var usageURL: URL { root.appendingPathComponent("summary-usage.json") }
    private var epoch = UUID()
    private var revision: UInt64 = 0
    private var previous: SavedState?
    private var usage: SummaryUsage?
    private var usageWritable = true
    private var usageLoaded = false
    private var writable = true
    private var loaded = false

    package init(root: URL) { self.root = root }

    package func load() throws -> RepositorySnapshot {
        if loaded, let previous { return RepositorySnapshot(state: previous, epoch: epoch) }
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        loadUsage()
        var state = SavedState()
        var warning: String?
        var migrate = false
        if fm.fileExists(atPath: boardURL.path) {
            do {
                let data = try Data(contentsOf: boardURL)
                struct Header: Decodable { var version: Int }
                switch try JSONDecoder().decode(Header.self, from: data).version {
                case 1:
                    state = try BoardArchive.decode(data)
                    migrate = true
                case 2:
                    let document = try JSONDecoder().decode(BoardDocument.self, from: data)
                    state = document.state
                    do {
                        let cache = try JSONDecoder().decode(ObservationCache.self, from: Data(contentsOf: cacheURL))
                        guard cache.version == 1, cache.generation == document.cacheGeneration else { throw RepositoryFailure.invalid }
                        var candidate = state
                        candidate.cards = cache.cards
                        candidate.summaries = cache.summaries
                        try BoardArchive.validate(candidate)
                        state = candidate
                    } catch {
                        warning = "History cache will be rebuilt. Your projects, notes and assignments are intact."
                        do { try preserve(cacheURL) }
                        catch {
                            // A full/read-only disk must not prevent loading valid curation.
                            // Disable writes so the original cache remains available for recovery.
                            writable = false
                            warning = "Your projects and notes loaded, but the damaged history cache could not be backed up. Saving is paused; check disk space and folder access, then relaunch."
                        }
                    }
                default: throw RepositoryFailure.futureVersion
                }
                try BoardArchive.validate(state)
            } catch {
                writable = false
                throw error
            }
        } else { state.onboardingComplete = false }
        if !usageWritable {
            state.aiEnabled = false
            warning = "Summary usage could not be read. Cloud summaries are paused; your board is available."
        } else if !fm.fileExists(atPath: usageURL.path) {
            usage = state.summaryUsage
            if let usage { try BoardArchive.write(BoardArchive.encode(usage), to: usageURL) }
        }
        state.summaryUsage = usage
        previous = state
        loaded = true
        if migrate {
            // Complete v1 archive is backed up before the installed document changes format.
            try backup(state, force: true)
            try commit(state)
        }
        return RepositorySnapshot(state: state, epoch: epoch, warning: warning)
    }

    package func save(_ state: SavedState, epoch: UUID, revision: UInt64) throws {
        guard writable else { throw RepositoryFailure.invalid }
        guard epoch == self.epoch, revision >= self.revision else { return }
        try BoardArchive.validate(state)
        if let previous { try backup(previous) }
        try commit(state)
        self.revision = revision
    }

    private func commit(_ state: SavedState) throws {
        let generation = UUID()
        let cache = ObservationCache(state, generation: generation)
        // The document is the commit point. A crash between these writes leaves
        // a mismatched cache, which load() can discard without losing curation.
        try BoardArchive.write(BoardArchive.encode(cache), to: cacheURL)
        try BoardArchive.write(BoardArchive.encode(BoardDocument(state, generation: generation)), to: boardURL)
        previous = state
        previous?.summaryUsage = usage
    }

    package func reserveSummary(limit: Int, day: String) throws -> SummaryUsage {
        loadUsage()
        guard usageWritable, writable, (1...1000).contains(limit) else { throw RepositoryFailure.usageUnavailable }
        let attempts = usage?.day == day ? usage!.attempts : 0
        guard attempts < limit else { throw RepositoryFailure.dailyLimit }
        let reservation = SummaryUsage(day: day, attempts: attempts + 1)
        do { try BoardArchive.write(BoardArchive.encode(reservation), to: usageURL) }
        catch { throw RepositoryFailure.usageUnavailable }
        usage = reservation
        previous?.summaryUsage = reservation
        return reservation
    }

    package func restore(from source: URL) throws -> RepositorySnapshot {
        loadUsage()
        var state = try BoardArchive.decode(Data(contentsOf: source))
        state.aiEnabled = false
        state.onboardingComplete = true
        // Restoring an export cannot reset this installation's spending ledger.
        state.summaryUsage = usage
        if let previous { try backup(previous, force: true) }
        else { try preserve(boardURL); try preserve(cacheURL) }
        try commit(state)
        epoch = UUID()
        revision = 0
        writable = true
        loaded = true
        return RepositorySnapshot(state: state, epoch: epoch)
    }

    package func export(_ state: SavedState, to destination: URL) throws {
        try BoardArchive.write(BoardArchive.data(state), to: destination)
    }

    private func loadUsage() {
        guard !usageLoaded else { return }
        usageLoaded = true
        guard FileManager.default.fileExists(atPath: usageURL.path) else { return }
        do {
            let value = try JSONDecoder().decode(SummaryUsage.self, from: Data(contentsOf: usageURL))
            guard value.attempts >= 0,
                  value.day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { throw RepositoryFailure.invalid }
            usage = value
        } catch { usageWritable = false }
    }

    private func preserve(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let folder = root.appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let target = folder.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).json")
        try BoardArchive.write(Data(contentsOf: url), to: target)
    }

    private func backup(_ state: SavedState, force: Bool = false) throws {
        let fm = FileManager.default
        let folder = root.appendingPathComponent("Backups", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.lastPathComponent.range(of: #"^board-[0-9]+-[0-9A-Fa-f-]+\.json$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        if !force, let latest = files.first,
           let date = try latest.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(date) < 3600 { return }
        let target = folder.appendingPathComponent("board-\(Int(Date().timeIntervalSince1970 * 1_000_000))-\(UUID().uuidString).json")
        try BoardArchive.write(BoardArchive.data(state), to: target)
        for old in files.dropFirst(6) { try fm.removeItem(at: old) }
    }
}
