import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor final class BoardStore: ObservableObject {
    @Published var saved = SavedState()
    @Published var needsOnboarding = false
    @Published var dataStatus: String?
    @Published var health: [String: String] = [:]
    @Published var selectedProject: String?
    @Published var parking = false
    @Published var search = ""
    @Published var error: String?
    @Published var readerError: String?
    @Published var scanning = true
    @Published var statusCheckMessage: String?
    @Published var aiStatus = "Summaries are off. Your saved key can be reused."
    @Published var credentialStatus: CredentialStatus = .checking
    @Published var savingKey = false
    @Published var isSummarizing = false
    @Published var summaryIssue: String?
    @Published var updatedAt: Date?
    @Published var todoNoteCard: Conversation?
    var onChange: (() -> Void)?
    private var worker: Process?
    private var pipe: Pipe?
    private var aiTask: Task<Void, Never>?
    private var cachedKey: String?
    private let credentials: any CredentialStorage
    private let summarize: @Sendable (String, String, String) async throws -> String
    private var skippedRequests: [String: String] = [:]
    private var summaryGeneration = UUID()
    private var saveTask: Task<Void, Never>?
    private var storageWritable = true
    private let persistence = StatePersistence()
    private let monitoringEnabled: Bool
    private var requestHashes: [String: (text: String, hash: String)] = [:]
    private var discoveryDays = 14
    private var reportingStatusCheck = false
    let root: URL
    var dataFile: URL { root.appendingPathComponent("board.json") }

    init(root: URL? = nil, start: Bool = true, credentials: any CredentialStorage = KeychainCredentials(), summarize: @escaping @Sendable (String, String, String) async throws -> String = { try await GPT.summarize($0, model: $1, key: $2) }) {
        self.monitoringEnabled = start
        self.credentials = credentials
        self.summarize = summarize
        self.root = root ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Agent Kanban", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if FileManager.default.fileExists(atPath: dataFile.path) {
                saved = try StatePersistence.decode(Data(contentsOf: dataFile))
                for i in saved.projects.indices where saved.projects[i].colorIndex == nil { saved.projects[i].colorIndex = ProjectColor.nextIndex(in: saved.projects) }
                for i in saved.projects.indices where saved.projects[i].symbolIndex == nil { saved.projects[i].symbolIndex = ProjectSymbol.nextIndex(in: saved.projects) }
                // Keep the last observed state while the initial scan runs.
                // Every saved card is included, even outside the discovery window.
            }
        } catch { self.error = "Could not load saved board. Your existing file has been preserved; saving is disabled until recovery."; storageWritable = false }
        if saved.aiEnabled { aiStatus = "Waiting for conversations…" }
        if !FileManager.default.fileExists(atPath: dataFile.path) { saved.onboardingComplete = false }
        needsOnboarding = start && saved.onboardingComplete == false
        if start && storageWritable && !needsOnboarding {
            startReader()
            Task { [weak self] in await self?.refreshKeyStatus() }
        }
    }
    var cards: [Conversation] { saved.cards }
    func disposition(_ c: Conversation) -> Disposition { saved.dispositions[c.id] ?? Disposition() }
    func column(_ c: Conversation) -> Column { Lifecycle.column(c, disposition(c)) }
    func project(_ c: Conversation) -> Project? { saved.projects.first { $0.id == disposition(c).projectID } }
    func count(_ col: Column) -> Int { cards.filter { !disposition($0).parked && column($0) == col }.count }
    var parkedCount: Int { cards.filter { disposition($0).parked }.count }
    var sourceWarnings: [String] {
        ["claude", "codex"].compactMap { provider in
            let name = provider == "claude" ? "Claude" : "Codex"
            if let status = health[provider], !status.hasPrefix("Connected"), !["Disabled", "Not installed", "No local sessions"].contains(where: status.hasPrefix) {
                return "\(name) updates paused · \(status.replacingOccurrences(of: "Unavailable · ", with: ""))"
            }
            let affected = cards.filter { $0.provider == provider && $0.observationIssue != nil }
            guard let issue = affected.first?.observationIssue else { return nil }
            return "\(name): \(affected.count) \(affected.count == 1 ? "history" : "histories") unreadable · \(issue)"
        }
    }
    func selectProject(_ id: String?) {
        selectedProject = id
        search = ""
    }
    var visible: [Conversation] {
        CardOrder.sorted(cards.filter { c in
            disposition(c).parked == parking && (selectedProject == nil || disposition(c).projectID == selectedProject) && (search.isEmpty || (c.title + " " + (project(c)?.name ?? "") + " " + (c.requests.last?.text ?? "") + " " + (disposition(c).todoNote ?? "")).localizedCaseInsensitiveContains(search))
        }, dispositions: saved.dispositions)
    }
    func summary(_ c: Conversation, _ r: RequestItem) -> String? {
        let id = c.id + ":" + r.id
        guard let s = saved.summaries[id] else { return nil }
        if requestHashes[id]?.text != r.text { requestHashes[id] = (r.text, Self.hash(r.text)) }
        guard s.inputHash == requestHashes[id]?.hash else { return nil }
        return s.text
    }
    nonisolated static func hash(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
    func changed() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled, storageWritable else { return }
            persistence.writeAsync(saved, to: dataFile) { [weak self] succeeded in
                if !succeeded { self?.error = "Could not save the board. Check available disk space and folder access." }
            }
        }
        onChange?()
    }
    func persist() {
        guard storageWritable else { return }
        if !persistence.writeSync(saved, to: dataFile) { error = "Could not save the board. Check available disk space and folder access." }
    }
    func setNote(_ id: String, _ text: String) {
        guard let i = saved.projects.firstIndex(where: { $0.id == id }) else { return }
        saved.projects[i].note = text; changed()
    }
    func setTodoNote(_ cardID: String, _ text: String) {
        guard let card = cards.first(where: { $0.id == cardID }) else { return }
        var d = disposition(card)
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        d.todoNote = note.isEmpty ? nil : note
        saved.dispositions[cardID] = d; changed()
    }
    func togglePriority(_ cardID: String) {
        guard let card = cards.first(where: { $0.id == cardID }) else { return }
        var d = disposition(card)
        d.priority = d.priority == true ? nil : true
        saved.dispositions[cardID] = d; changed()
    }
    func addProject(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let p = Project(name: name, colorIndex: ProjectColor.nextIndex(in: saved.projects), symbolIndex: ProjectSymbol.nextIndex(in: saved.projects)); saved.projects.append(p); selectedProject = p.id; changed()
    }
    func renameProject(_ id: String, _ name: String) {
        guard let i = saved.projects.firstIndex(where: { $0.id == id }), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        saved.projects[i].name = name; changed()
    }
    func assign(_ c: Conversation, to id: String) {
        var d = disposition(c); d.projectID = id; d.assignmentLocked = true; saved.dispositions[c.id] = d; changed()
    }
    func mark(_ c: Conversation, _ col: Column) {
        guard col != .running && col != .unknown else { return }
        let enteringTodo = col == .todo && column(c) != .todo
        var d = disposition(c)
        if col == .dealtWith { d.acknowledgedRevision = c.revision; d.manualColumn = nil; d.manualRevision = nil }
        else { d.acknowledgedRevision = nil; d.manualColumn = col; d.manualRevision = c.revision }
        d.todoRequestID = col == .todo ? c.requests.last?.id ?? "" : nil
        if col == .todo {
            d.parked = false; d.parkedManually = false
        }
        saved.dispositions[c.id] = d; changed()
        if enteringTodo { todoNoteCard = c }
    }
    func park(_ c: Conversation, _ value: Bool) {
        var d = disposition(c); d.parked = value; d.parkedManually = value
        if !value { d.restoredAt = Date().timeIntervalSince1970 }
        saved.dispositions[c.id] = d; changed()
    }
    func open(_ c: Conversation) {
        guard let url = c.navigationURL else {
            error = "This conversation has an invalid link. Try Retry status to reload it from \(c.providerName)."
            return
        }
        if !NSWorkspace.shared.open(url) { error = "Could not open \(c.providerName). Check that it is installed." }
    }
    func retryStatus() {
        guard !scanning else { return }
        reportingStatusCheck = true
        statusCheckMessage = nil
        startReader()
    }
    static func readerArguments(script: String, days: Int, parentPID: Int32, trackedIDs: [String], healthLog: String? = nil) -> [String] {
        ["-I", "-u", script, "--watch", "--days", String(days), "--parent-pid", String(parentPID)]
            + (healthLog.map { ["--health-log", $0] } ?? [])
            + trackedIDs.sorted().flatMap { ["--tracked-id", $0] }
    }
    func startReader(days: Int? = nil) {
        guard monitoringEnabled else { return }
        if let days { discoveryDays = days }
        if worker?.isRunning == true { worker?.terminate() }
        scanning = true
        readerError = nil
        let resource = Bundle.main.resourceURL?.appendingPathComponent("reader.py")
        let local = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/reader.py")
        let script = [resource, local].compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
        guard let script else { error = "Session reader is missing. Rebuild the app bundle."; scanning = false; finishStatusCheck(failure: "Status check failed"); return }
        let p = Process(), output = Pipe()
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Python/bin/python3")
        p.executableURL = bundled.flatMap { FileManager.default.isExecutableFile(atPath: $0.path) ? $0 : nil } ?? URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = Self.readerArguments(script: script.path, days: discoveryDays, parentPID: ProcessInfo.processInfo.processIdentifier, trackedIDs: cards.map(\.id), healthLog: root.appendingPathComponent("status-health.json").path)
        p.arguments = ["-I", "-B"] + (p.arguments ?? [])
        for provider in privacy.disabledProviders.sorted() { p.arguments! += ["--disable-provider", provider] }
        if let path = privacy.codexHome, !path.isEmpty { p.arguments! += ["--codex-home", path] }
        if let path = privacy.claudeHome, !path.isEmpty { p.arguments! += ["--claude-home", path] }
        p.currentDirectoryURL = URL(fileURLWithPath: "/")
        p.standardOutput = output
        p.standardError = FileHandle.nullDevice
        worker = p; pipe = output
        let generation = UUID()
        readerGeneration = generation
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard let self, self.readerGeneration == generation, self.scanning else { return }
            self.scanning = false
            self.readerError = "The session reader has not responded. Try Retry status; check macOS file-access prompts if it remains unavailable."
            self.statusCheckMessage = "Status check timed out"
            self.finishStatusCheck(failure: "Status check timed out")
        }
        Task.detached { [weak self] in
            var buffer = Data()
            do {
                try p.run()
                while p.isRunning {
                    let chunk = output.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    while let newline = buffer.firstIndex(of: 10) {
                        let line = buffer.prefix(upTo: newline)
                        buffer.removeSubrange(...newline)
                        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: line) {
                            await self?.receive(snapshot, generation: generation)
                        } else {
                            await self?.readerInvalid(generation)
                        }
                    }
                }
                await self?.readerEnded(generation)
            } catch { await self?.readerEnded(generation) }
        }
    }
    private var readerGeneration = UUID()
    private func readerInvalid(_ generation: UUID) {
        guard readerGeneration == generation else { return }
        scanning = false
        readerError = "The session reader returned an unsupported format. Existing projects and notes have been preserved."
        statusCheckMessage = "Status check failed"
        finishStatusCheck(failure: "Status check failed")
    }
    private func readerEnded(_ generation: UUID) {
        guard readerGeneration == generation else { return }
        scanning = false
        health = ["claude": "Unavailable · reader stopped", "codex": "Unavailable · reader stopped"]
        for i in saved.cards.indices { saved.cards[i].observationIssue = "Reader stopped" }
        statusCheckMessage = "Reader stopped · reconnecting…"
        finishStatusCheck(failure: "Status check failed")
        onChange?()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.readerGeneration == generation else { return }
            self.startReader()
        }
    }
    private func receive(_ snapshot: Snapshot, generation: UUID) {
        guard readerGeneration == generation else { return }
        apply(snapshot)
    }
    private func finishStatusCheck(failure: String? = nil) {
        guard reportingStatusCheck else { return }
        reportingStatusCheck = false
        if let failure { statusCheckMessage = failure }
        else {
            let unreadable = cards.filter { $0.observationIssue != nil }.count
            if unreadable > 0 {
                statusCheckMessage = "Still cannot read \(unreadable) histories · retrying automatically"
                return
            }
            let unavailable = cards.filter { column($0) == .unknown }.count
            statusCheckMessage = unavailable == 0 ? "Status checked · all available" : "Status checked · \(unavailable) still unavailable"
        }
    }
    func apply(_ snapshot: Snapshot) {
        if health != snapshot.health { health = snapshot.health }
        if scanning { scanning = false }
        if readerError != nil { readerError = nil }
        if updatedAt == nil || Int(updatedAt!.timeIntervalSince1970 / 60) != Int(snapshot.scannedAt / 60) {
            updatedAt = Date(timeIntervalSince1970: snapshot.scannedAt)
        }
        var next = saved
        var byID = Dictionary(uniqueKeysWithValues: saved.cards.map { ($0.id, $0) })
        let receivedIDs = Set(snapshot.cards.map(\.id))
        for var c in snapshot.cards {
            if c.observationIssue != nil || ["History temporarily unavailable", "History unavailable"].contains(c.reason) {
                c.observationIssue = c.observationIssue ?? c.reason
                if let old = byID[c.id] {
                    c.requests = old.requests; c.response = old.response
                    c.eventID = old.eventID; c.eventTime = old.eventTime
                    c.state = old.state; c.reason = old.reason
                }
            }
            var d = Lifecycle.reconcile(byID[c.id], c, disposition(c), now: snapshot.scannedAt, healthy: snapshot.health[c.provider]?.hasPrefix("Connected") == true && c.observationIssue == nil)
            if d.projectID == nil {
                if let p = next.projects.first(where: { $0.folders.contains(c.folder) && !c.folder.isEmpty }) { d.projectID = p.id }
                else {
                    let name = c.folder.isEmpty ? "Ungrouped" : URL(fileURLWithPath: c.folder).lastPathComponent
                    let p = Project(name: name, folders: c.folder.isEmpty ? [] : [c.folder], colorIndex: ProjectColor.nextIndex(in: next.projects), symbolIndex: ProjectSymbol.nextIndex(in: next.projects)); next.projects.append(p); d.projectID = p.id
                }
            }
            next.dispositions[c.id] = d
            byID[c.id] = c
        }
        for (id, var c) in byID {
            if snapshot.health[c.provider]?.hasPrefix("Connected") != true {
                c.observationIssue = snapshot.health[c.provider]?.replacingOccurrences(of: "Unavailable · ", with: "") ?? "Source unavailable"
                byID[id] = c
            } else if !receivedIDs.contains(id) {
                c.state = .unknown; c.reason = "Conversation not found in source history"; c.observationIssue = nil; byID[id] = c
            }
        }
        next.cards = byID.values.sorted { $0.id < $1.id }
        if next != saved {
            if !reportingStatusCheck { statusCheckMessage = nil }
            saved = next; changed()
        }
        finishStatusCheck(failure: ["claude", "codex"].contains(where: { snapshot.health[$0]?.hasPrefix("Connected") != true }) ? "Status check failed · source unavailable" : nil)
        queueSummaries()
    }
    var privacy: PrivacyOptions { saved.privacy ?? PrivacyOptions() }
    var summaryAttemptsToday: Int { saved.summaryUsage?.day == SummaryUsage.today() ? saved.summaryUsage!.attempts : 0 }
    func completeOnboarding() { saved.onboardingComplete = true; needsOnboarding = false; persist(); startReader() }
    func setProvider(_ provider: String, enabled: Bool) {
        var options = privacy
        if enabled { options.disabledProviders.remove(provider) } else { options.disabledProviders.insert(provider) }
        saved.privacy = options; cancelSummaries(); changed()
        if !needsOnboarding { startReader(); queueSummaries() }
    }
    func setSourceHome(_ provider: String, path: String) {
        var options = privacy
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == "codex" { options.codexHome = trimmed.isEmpty ? nil : (trimmed as NSString).expandingTildeInPath }
        else { options.claudeHome = trimmed.isEmpty ? nil : (trimmed as NSString).expandingTildeInPath }
        saved.privacy = options; changed(); startReader()
    }
    func setSummaryExcluded(_ project: String, excluded: Bool) {
        cancelSummaries()
        var options = privacy
        if excluded { options.excludedSummaryProjects.insert(project) } else { options.excludedSummaryProjects.remove(project) }
        saved.privacy = options; changed(); queueSummaries()
    }
    func setDailyLimit(_ limit: Int) {
        var options = privacy; options.dailySummaryLimit = min(1000, max(1, limit))
        saved.privacy = options; changed(); queueSummaries()
    }
    func summaryAllowed(_ card: Conversation) -> Bool {
        !privacy.disabledProviders.contains(card.provider) && !privacy.excludedSummaryProjects.contains(disposition(card).projectID ?? "")
    }
    private func reserveSummaryAttempt() -> Bool {
        guard summaryAttemptsToday < privacy.dailySummaryLimit else {
            aiStatus = "Daily limit reached (\(privacy.dailySummaryLimit)). Resumes tomorrow; change the limit in Settings."; return false
        }
        saved.summaryUsage = SummaryUsage(day: SummaryUsage.today(), attempts: summaryAttemptsToday + 1)
        // Reserve before sending, including failures/retries, so restarting cannot reset the cap.
        guard storageWritable, persistence.writeSync(saved, to: dataFile) else {
            summaryIssue = "Cannot save usage. Summaries paused to preserve your daily limit."; aiStatus = summaryIssue!; return false
        }
        return true
    }
    func deleteKey() async {
        guard !savingKey else { return }
        savingKey = true
        defer { savingKey = false }
        cancelSummaries(); saved.aiEnabled = false; changed()
        do {
            try await credentials.delete(); cachedKey = nil; credentialStatus = .missing
            summaryIssue = nil; aiStatus = "Key deleted. Summaries are off."
        } catch { summaryIssue = error.localizedDescription; aiStatus = "Could not delete the key. " + error.localizedDescription }
    }
    func exportBoard(to destination: URL) {
        dataStatus = StatePersistence.export(saved, to: destination) ? "Board exported. The file contains private request text and notes; keep it secure." : "Could not export the board."
    }
    func restoreBoard(from source: URL) {
        do {
            var restored = try StatePersistence.decode(Data(contentsOf: source))
            restored.aiEnabled = false // Importing a file never enables cloud processing.
            // Keep this installation's usage reservation; imports cannot reset spending controls.
            restored.summaryUsage = saved.summaryUsage
            guard persistence.restoreSync(restored, to: dataFile) else { throw CocoaError(.fileWriteUnknown) }
            cancelSummaries(); saveTask?.cancel(); saved = restored; storageWritable = true
            selectedProject = nil; search = ""; error = nil; dataStatus = "Board restored. Summaries are off. The previous board is in Backups (or Recovery if it was unreadable)."
            startReader(); onChange?()
        } catch { dataStatus = "Could not restore this file. Use a valid kanbanana board export; your current board is unchanged." }
    }
    func exportDiagnostics(to destination: URL) {
        let report: [String: Any] = ["appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "architecture": "arm64", "providerVersions": IntegrationInfo.versions,
            "health": Dictionary(uniqueKeysWithValues: ["claude", "codex"].map { ($0, IntegrationInfo.safeHealth(health[$0])) }),
            "counts": Dictionary(uniqueKeysWithValues: Column.allCases.map { ($0.rawValue, count($0)) }),
            "captured": cards.count, "parked": parkedCount, "summariesEnabled": saved.aiEnabled,
            "readerResponded": updatedAt != nil]
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: destination, options: .atomic)
            dataStatus = "Diagnostics exported: versions and aggregate counts only."
        } catch { dataStatus = "Could not export diagnostics." }
    }
    func stop() { readerGeneration = UUID(); worker?.terminate(); aiTask?.cancel(); saveTask?.cancel(); persist() }
    func refreshKeyStatus() async {
        let status = await credentials.status()
        if !savingKey { credentialStatus = cachedKey == nil ? status : .saved }
    }
    @discardableResult func saveKey(_ enteredKey: String) async -> Bool {
        let key = enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !savingKey, !key.isEmpty else { return false }
        cancelSummaries()
        savingKey = true
        aiStatus = "Saving API key to Keychain…"
        defer { savingKey = false }
        do {
            try await credentials.save(key)
            cachedKey = key
            credentialStatus = .saved
            summaryIssue = nil
            skippedRequests.removeAll()
            changed()
            aiStatus = "Key saved. Ready to summarize."
            // Clear the saving gate before starting the queue.
            savingKey = false
            if saved.aiEnabled { queueSummaries() }
            return true
        } catch {
            aiStatus = "Key was not saved. " + error.localizedDescription
            summaryIssue = aiStatus
            return false
        }
    }
    private func cancelSummaries() {
        aiTask?.cancel(); aiTask = nil; summaryGeneration = UUID(); isSummarizing = false
    }
    func setAIEnabled(_ enabled: Bool) {
        cancelSummaries()
        saved.aiEnabled = enabled
        summaryIssue = nil
        changed()
        aiStatus = enabled ? "Preparing summaries…" : "Summaries are off. Your saved key can be reused."
        if enabled { queueSummaries() }
    }
    func retrySummaries() {
        skippedRequests.removeAll()
        if credentialStatus == .accessNeeded { cachedKey = nil }
        setAIEnabled(true)
    }
    func setModel(_ value: String) {
        let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model != saved.model else { return }
        cancelSummaries()
        saved.model = model
        summaryIssue = nil
        skippedRequests.removeAll()
        changed()
        queueSummaries()
    }
    private func summaryKey() async -> String? {
        if let cachedKey { return cachedKey }
        aiStatus = "Reading saved key from Keychain…"
        do {
            let key = try await credentials.load()
            guard !Task.isCancelled else { return nil }
            cachedKey = key
            credentialStatus = .saved
            return key
        } catch {
            guard !Task.isCancelled else { return nil }
            if let failure = error as? Keychain.Failure, failure.isMissing { credentialStatus = .missing }
            else { credentialStatus = .accessNeeded }
            summaryIssue = error.localizedDescription
            aiStatus = "Summaries paused. " + error.localizedDescription
            return nil
        }
    }
    private func pendingSummary(_ c: Conversation, _ r: RequestItem) -> Bool {
        let id = c.id + ":" + r.id
        return summaryAllowed(c) && (summary(c, r) == nil || saved.summaries[id].map(SummaryStyle.needsRefresh) == true)
            && skippedRequests[id] != Self.hash(r.text)
    }
    func queueSummaries() {
        guard saved.aiEnabled, aiTask == nil, !savingKey, summaryIssue == nil else { return }
        let recent = cards.sorted { $0.updated > $1.updated }
        var pending = recent.compactMap { c -> (Conversation, RequestItem)? in
            guard let r = c.requests.last, pendingSummary(c, r) else { return nil }; return (c, r)
        }
        // Refresh already-summarized history in the new voice. Unrequested history
        // remains untouched, and old summaries stay readable until replaced.
        if pending.count < 12 {
            history: for c in recent {
                for r in c.requests.dropLast().reversed() {
                    guard let old = saved.summaries[c.id + ":" + r.id], SummaryStyle.needsRefresh(old),
                          old.inputHash == Self.hash(r.text), pendingSummary(c, r) else { continue }
                    pending.append((c, r))
                    if pending.count == 12 { break history }
                }
            }
        }
        guard !pending.isEmpty else { aiStatus = finishedSummaryStatus; return }
        runSummaries(Array(pending.prefix(12)), history: false)
    }
    func summarizeHistory(_ c: Conversation) {
        guard saved.aiEnabled, aiTask == nil, !savingKey, summaryIssue == nil else { return }
        let pending = c.requests.reversed().filter { pendingSummary(c, $0) }.map { (c, $0) }
        runSummaries(pending, history: true)
    }
    private var finishedSummaryStatus: String {
        skippedRequests.isEmpty ? "Latest requests summarized." : "Summaries up to date; \(skippedRequests.count) requests kept as excerpts. Retry to try them again."
    }
    private func runSummaries(_ pending: [(Conversation, RequestItem)], history: Bool) {
        let generation = UUID(); summaryGeneration = generation
        let model = saved.model
        isSummarizing = true
        aiTask = Task {
            defer { if summaryGeneration == generation { aiTask = nil; isSummarizing = false } }
            guard let key = await summaryKey(), !Task.isCancelled else { return }
            for (c, r) in pending {
                guard !Task.isCancelled, saved.aiEnabled else { return }
                guard summaryAllowed(c) else { continue }
                guard reserveSummaryAttempt() else { return }
                do {
                    aiStatus = history ? "Summarizing request history…" : "Summarizing latest requests…"
                    let value = try await summarize(r.text, model, key)
                    guard !Task.isCancelled, summaryGeneration == generation else { return }
                    saved.summaries[c.id + ":" + r.id] = Summary(text: value, inputHash: Self.hash(r.text), styleVersion: SummaryStyle.version); changed()
                } catch {
                    if Task.isCancelled { return }
                    if let failure = error as? GPT.Failure, failure.requestOnly {
                        skippedRequests[c.id + ":" + r.id] = Self.hash(r.text)
                        continue
                    }
                    summaryIssue = error.localizedDescription
                    aiStatus = "Summaries paused. " + error.localizedDescription
                    // Preserve the user's enabled preference and saved key. An API
                    // failure is not a request to switch the feature off or delete it.
                    return
                }
            }
            aiStatus = finishedSummaryStatus
        }
    }
}
