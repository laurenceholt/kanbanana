import AppKit
import Combine
import Foundation
import KanbananaCore
import KanbananaServices

/// The main-actor coordinator owns board mutations and presentation selection.
/// It delegates process, disk, credential and network effects to services.
@MainActor final class BoardStore: ObservableObject {
    @Published private(set) var saved = SavedState()
    @Published private(set) var isLoading = true
    @Published private(set) var providerHealth: [ProviderID: ProviderHealth] = [:]
    @Published var needsOnboarding = false
    @Published var dataStatus: String?
    @Published var selectedProject: String?
    @Published var parking = false
    @Published var search = ""
    @Published var error: String?
    @Published var readerError: String?
    @Published var scanning = true
    @Published var statusCheckMessage: String?
    @Published var updatedAt: Date?
    @Published var todoNoteCard: Conversation?
    @Published private(set) var historyLoading = Set<String>()
    @Published private(set) var historyHasMore: [String: Bool] = [:]
    @Published private(set) var historyError: [String: String] = [:]
    var onChange: (() -> Void)?

    private let repository: any BoardRepository
    private let monitor: any SessionMonitoring
    private let credentials: any CredentialStorage
    private let summarize: @Sendable (String, String, String) async throws -> String
    private let clock: ServiceClock
    private let monitoringEnabled: Bool
    private var storageWritable = true
    private var isStopped = false
    private var epoch = UUID()
    private var revision: UInt64 = 0
    private var discoveryDays = 14
    private var waitingForProviders = Set<ProviderID>()
    private var saveTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var summaryObservation: AnyCancellable?
    private var requestHashes: [String: (text: String, hash: String)] = [:]
    private var historyCursors: [String: String] = [:]
    let root: URL
    var dataFile: URL { root.appendingPathComponent("board.json") }

    private lazy var summaries = SummaryScheduler(credentials: credentials, repository: repository, clock: clock,
        summarize: summarize, state: { [weak self] in self?.saved ?? SavedState() },
        received: { [weak self] id, summary in
            guard let self else { return }
            self.saved.summaries[id] = summary
            self.changed()
        }, reserved: { [weak self] usage in self?.saved.summaryUsage = usage })

    init(root: URL? = nil, start: Bool = true, initialState: SavedState? = nil,
         repository: (any BoardRepository)? = nil, monitor: (any SessionMonitoring)? = nil,
         credentials: any CredentialStorage = KeychainCredentials(), clock: ServiceClock = ServiceClock(),
         summarize: @escaping @Sendable (String, String, String) async throws -> String = { try await GPT.summarize($0, model: $1, key: $2) }) {
        let root = root ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Agent Kanban", isDirectory: true)
        self.root = root
        self.repository = repository ?? FileBoardRepository(root: root)
        self.monitor = monitor ?? ReaderSupervisor(clock: clock)
        self.credentials = credentials
        self.clock = clock
        self.summarize = summarize
        monitoringEnabled = start
        summaryObservation = summaries.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        loadTask = Task { [weak self] in await self?.loadInitial(initialState) }
    }

    static func loaded(root: URL? = nil, start: Bool = true, initialState: SavedState? = nil,
                       credentials: any CredentialStorage = KeychainCredentials(),
                       summarize: @escaping @Sendable (String, String, String) async throws -> String = { try await GPT.summarize($0, model: $1, key: $2) }) async -> BoardStore {
        let store = BoardStore(root: root, start: start, initialState: initialState, credentials: credentials, summarize: summarize)
        await store.ready()
        return store
    }
    func ready() async { await loadTask?.value }

    private func loadInitial(_ initial: SavedState?) async {
        defer { isLoading = false }
        do {
            let loaded = try await repository.load()
            epoch = loaded.epoch
            saved = initial ?? loaded.state
            dataStatus = loaded.warning
            prepareProjectAppearance()
            needsOnboarding = monitoringEnabled && saved.onboardingComplete == false
            if monitoringEnabled && !needsOnboarding && !isStopped {
                startReader()
                await summaries.refreshKeyStatus()
            } else { scanning = false }
            onChange?()
        } catch {
            storageWritable = false
            scanning = false
            self.error = "Could not load saved board. Your existing file has been preserved; saving is disabled until recovery."
        }
    }
    private func prepareProjectAppearance() {
        for i in saved.projects.indices where saved.projects[i].colorIndex == nil {
            saved.projects[i].colorIndex = ProjectColor.nextIndex(in: saved.projects)
        }
        for i in saved.projects.indices where saved.projects[i].symbolIndex == nil {
            saved.projects[i].symbolIndex = ProjectSymbol.nextIndex(in: saved.projects)
        }
    }

    var cards: [Conversation] { saved.cards }
    var health: [String: String] { Dictionary(uniqueKeysWithValues: providerHealth.map { ($0.key.rawValue, $0.value.message) }) }
    var privacy: PrivacyOptions { saved.privacy ?? PrivacyOptions() }
    var aiStatus: String { summaries.status }
    var credentialStatus: CredentialStatus { summaries.credentialStatus }
    var savingKey: Bool { summaries.savingKey }
    var isSummarizing: Bool { summaries.isRunning }
    var summaryIssue: String? { summaries.issue }
    var summaryAttemptsToday: Int { saved.summaryUsage?.day == SummaryUsage.today(clock.now()) ? saved.summaryUsage!.attempts : 0 }
    var parkedCount: Int { cards.filter { disposition($0).parked }.count }
    func disposition(_ card: Conversation) -> Disposition { saved.dispositions[card.id] ?? Disposition() }
    func column(_ card: Conversation) -> Column { Lifecycle.column(card, disposition(card)) }
    func project(_ card: Conversation) -> Project? { saved.projects.first { $0.id == disposition(card).projectID } }
    func count(_ column: Column) -> Int { cards.filter { !disposition($0).parked && self.column($0) == column }.count }
    var sourceWarnings: [String] {
        ProviderID.allCases.compactMap { provider in
            if let health = providerHealth[provider], ![.connected, .disabled, .notInstalled, .noSessions].contains(health.status) {
                return "\(provider.title) updates paused · \(health.issue ?? health.message)"
            }
            let affected = cards.filter { $0.provider == provider.rawValue && $0.observationIssue != nil }
            guard let issue = affected.first?.observationIssue else { return nil }
            return "\(provider.title): \(affected.count) histories unreadable · \(issue)"
        }
    }
    var visible: [Conversation] {
        CardOrder.sorted(cards.filter { card in
            disposition(card).parked == parking
            && (selectedProject == nil || disposition(card).projectID == selectedProject)
            && (search.isEmpty || (card.title + " " + (project(card)?.name ?? "") + " "
                + (card.requests.last?.text ?? "") + " " + (disposition(card).todoNote ?? ""))
                .localizedCaseInsensitiveContains(search))
        }, dispositions: saved.dispositions)
    }
    func selectProject(_ id: String?) { selectedProject = id; search = "" }
    nonisolated static func hash(_ text: String) -> String { RequestDigest.hash(text) }
    func summary(_ card: Conversation, _ request: RequestItem) -> String? {
        let id = card.id + ":" + request.id
        guard let summary = saved.summaries[id] else { return nil }
        if requestHashes[id]?.text != request.text { requestHashes[id] = (request.text, Self.hash(request.text)) }
        return summary.inputHash == requestHashes[id]?.hash ? summary.text : nil
    }

    private func changed() {
        revision += 1
        saveTask?.cancel()
        let state = saved, token = epoch, number = revision
        saveTask = Task { [weak self, repository] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, self?.storageWritable == true else { return }
                try await repository.save(state, epoch: token, revision: number)
            } catch is CancellationError { }
            catch { self?.error = "Could not save the board. Check available disk space and folder access." }
        }
        onChange?()
    }
    func persist() async {
        await ready()
        saveTask?.cancel()
        guard storageWritable else { return }
        revision += 1
        do { try await repository.save(saved, epoch: epoch, revision: revision) }
        catch { self.error = "Could not save the board. Check available disk space and folder access." }
    }
    private func send(_ command: BoardCommand) {
        guard !isLoading else { return }
        saved.apply(command, now: clock.now().timeIntervalSince1970)
        changed()
    }
    func setNote(_ id: String, _ text: String) { send(.projectNote(id, text)) }
    func setTodoNote(_ id: String, _ text: String) { send(.todoNote(id, text)) }
    func togglePriority(_ id: String) { send(.togglePriority(id)) }
    func addProject(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let project = Project(name: name, colorIndex: ProjectColor.nextIndex(in: saved.projects), symbolIndex: ProjectSymbol.nextIndex(in: saved.projects))
        send(.addProject(project))
        selectedProject = project.id
    }
    func renameProject(_ id: String, _ name: String) { send(.renameProject(id, name)) }
    func setProjectColor(_ id: String, _ index: Int) {
        if ProjectColor.palette.indices.contains(index) { send(.projectColor(id, index)) }
    }
    func setProjectSymbol(_ id: String, _ index: Int) {
        if ProjectSymbol.palette.indices.contains(index) { send(.projectSymbol(id, index)) }
    }
    func assign(_ card: Conversation, to id: String) { send(.assign(card.id, id)) }
    func mark(_ card: Conversation, _ column: Column) {
        let enteringTodo = column == .todo && self.column(card) != .todo
        send(.mark(card.id, column))
        if enteringTodo { todoNoteCard = card }
    }
    func park(_ card: Conversation, _ value: Bool) { send(.park(card.id, value)) }
    func open(_ card: Conversation) {
        guard let url = card.navigationURL else { error = "This conversation has an invalid link. Retry status to reload it."; return }
        if !NSWorkspace.shared.open(url) { error = "Could not open \(card.providerName). Check that it is installed." }
    }

    func startReader(days: Int? = nil) {
        guard monitoringEnabled, storageWritable, !isStopped else { return }
        if let days { discoveryDays = days }
        scanning = true
        readerError = nil
        waitingForProviders = Set(ProviderID.allCases)
        do {
            let tracked = Set(cards.map(\.id)).union(saved.dispositions.keys)
            let config = try ReaderConfiguration.installed(days: discoveryDays, trackedIDs: Array(tracked), privacy: privacy)
            monitor.start(config) { [weak self] in self?.apply($0) }
        } catch {
            readerError = error.localizedDescription
            scanning = false
        }
    }
    func retryStatus() {
        statusCheckMessage = "Checking status…"
        startReader()
    }
    func apply(_ snapshot: ProviderSnapshot) {
        guard !isLoading, !isStopped else { return }
        if providerHealth[snapshot.provider] != snapshot.health { providerHealth[snapshot.provider] = snapshot.health }
        waitingForProviders.remove(snapshot.provider)
        if scanning != !waitingForProviders.isEmpty { scanning = !waitingForProviders.isEmpty }
        if readerError != nil { readerError = nil }
        if updatedAt == nil || Int(updatedAt!.timeIntervalSince1970 / 60) != Int(snapshot.scannedAt / 60) {
            updatedAt = Date(timeIntervalSince1970: snapshot.scannedAt)
        }
        let next = BoardReconciler.apply(snapshot, to: saved)
        if next != saved {
            saved = next
            prepareProjectAppearance()
            changed()
        } else { onChange?() }
        if !scanning {
            let unreadable = cards.filter { $0.observationIssue != nil || column($0) == .unknown }.count
            let message = unreadable == 0 ? "Status checked · all available" : "\(unreadable) histories unavailable · retrying automatically"
            if statusCheckMessage != message { statusCheckMessage = message }
        }
        queueSummaries()
    }
    func completeOnboarding() {
        saved.onboardingComplete = true
        needsOnboarding = false
        changed()
        startReader()
    }
    func setProvider(_ provider: String, enabled: Bool) {
        var options = privacy
        if enabled { options.disabledProviders.remove(provider) } else { options.disabledProviders.insert(provider) }
        saved.privacy = options
        summaries.cancel()
        changed()
        if !needsOnboarding { startReader(); queueSummaries() }
    }
    func setSourceHome(_ provider: String, path: String) {
        var options = privacy
        let value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = value.isEmpty ? nil : (value as NSString).expandingTildeInPath
        if provider == "codex" { options.codexHome = home } else { options.claudeHome = home }
        saved.privacy = options
        changed()
        startReader()
    }
    func setSummaryExcluded(_ project: String, excluded: Bool) {
        var options = privacy
        if excluded { options.excludedSummaryProjects.insert(project) } else { options.excludedSummaryProjects.remove(project) }
        saved.privacy = options
        changed()
        summaries.settingsChanged()
    }
    func setDailyLimit(_ limit: Int) {
        var options = privacy
        options.dailySummaryLimit = min(1000, max(1, limit))
        saved.privacy = options
        changed()
        summaries.settingsChanged()
    }
    func summaryAllowed(_ card: Conversation) -> Bool { SummaryScheduler.allowed(card, in: saved) }
    func setAIEnabled(_ value: Bool) { saved.aiEnabled = value; changed(); summaries.settingsChanged() }
    func setModel(_ value: String) {
        let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model != saved.model else { return }
        saved.model = model
        changed()
        summaries.settingsChanged()
    }
    func queueSummaries() { if storageWritable && !isLoading && !isStopped { summaries.queue() } }
    func summarizeHistory(_ card: Conversation) { if storageWritable { summaries.queue(history: card.id) } }
    func retrySummaries() { saved.aiEnabled = true; changed(); summaries.retry() }
    func refreshKeyStatus() async { await summaries.refreshKeyStatus() }
    @discardableResult func saveKey(_ key: String) async -> Bool { await summaries.saveKey(key) }
    func deleteKey() async {
        guard !savingKey else { return }
        saved.aiEnabled = false
        changed()
        await summaries.deleteKey()
    }
    func stop() async {
        isStopped = true
        summaries.cancel()
        await monitor.stop()
        await persist()
    }

    func loadHistory(_ cardID: String, earlier: Bool = false) async {
        guard !historyLoading.contains(cardID), let card = cards.first(where: { $0.id == cardID }), monitoringEnabled else { return }
        let token = epoch
        historyLoading.insert(cardID)
        historyError[cardID] = nil
        defer { historyLoading.remove(cardID) }
        do {
            let page = try await monitor.history(card, before: earlier ? historyCursors[cardID] : nil)
            guard token == epoch, let index = saved.cards.firstIndex(where: { $0.id == cardID }) else { return }
            saved.cards[index].requests = RequestHistory.merging(saved.cards[index].requests, page.requests, older: true)
            historyCursors[cardID] = page.requests.first?.id
            historyHasMore[cardID] = page.hasMore
            changed()
        } catch {
            if token == epoch && !(error is CancellationError) {
                historyError[cardID] = "Could not load earlier history. Retry when the source is available."
            }
        }
    }
    func exportBoard(to destination: URL) async {
        do {
            try await repository.export(saved, to: destination)
            dataStatus = "Board exported. The file contains private request text and notes; keep it secure."
        } catch { dataStatus = "Could not export the board." }
    }
    func restoreBoard(from source: URL) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; startReader() }
        summaries.cancel()
        saveTask?.cancel()
        await monitor.stop()
        do {
            let restored = try await repository.restore(from: source)
            saved = restored.state
            epoch = restored.epoch
            revision = 0
            storageWritable = true
            requestHashes.removeAll()
            historyCursors.removeAll()
            historyHasMore.removeAll()
            prepareProjectAppearance()
            selectedProject = nil
            search = ""
            error = nil
            dataStatus = "Board restored. Summaries are off. The previous board is in Backups or Recovery."
            onChange?()
        } catch { dataStatus = "Could not restore this file. Use a valid kanbanana board export; your current board is unchanged." }
    }
    func exportDiagnostics(to destination: URL) async {
        let report: [String: Any] = ["appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString, "architecture": "arm64",
            "providerVersions": IntegrationInfo.versions,
            "health": Dictionary(uniqueKeysWithValues: providerHealth.map { ($0.key.rawValue, $0.value.status.rawValue) }),
            "counts": Dictionary(uniqueKeysWithValues: Column.allCases.map { ($0.rawValue, count($0)) }),
            "captured": cards.count, "parked": parkedCount, "summariesEnabled": saved.aiEnabled,
            "readerResponded": updatedAt != nil]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try await Task.detached(priority: .utility) { try data.write(to: destination, options: .atomic) }.value
            dataStatus = "Diagnostics exported: versions and aggregate counts only."
        } catch { dataStatus = "Could not export diagnostics." }
    }
}
