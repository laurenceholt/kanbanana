import Foundation
import KanbananaCore
import KanbananaServices

/// Synthetic fixtures shared by --demo, previews and UI regression tests.
/// This factory never opens a provider's history or the user's credential store.
enum DemoData {
    @MainActor static func showHealth(in store: BoardStore) {
        for provider in ProviderID.allCases {
            store.apply(ProviderSnapshot(provider: provider, cards: [], health: ProviderHealth(.connected),
                inventoryComplete: false, knownIDs: Set(store.cards.filter { $0.provider == provider.rawValue }.map(\.id)),
                scannedAt: Date().timeIntervalSince1970, completeHistory: false))
        }
    }
    static func state(mode: String = "focus", now: Double = Date().timeIntervalSince1970, priority: Bool = true) -> SavedState {
        var state = SavedState()
        state.onboardingComplete = true
        let weather = Project(id: "demo-weather", name: "Pocket weather", note: "Ship a calm, accessible forecast for the weekend.", colorIndex: 0, symbolIndex: 8)
        let trails = Project(id: "demo-trails", name: "Trail guide", note: "Find three walks reachable by train.", colorIndex: 1, symbolIndex: 10)
        let writing = Project(id: "demo-notes", name: "Launch notes", note: "Explain the first release in plain English.", colorIndex: 3, symbolIndex: 1)
        state.projects = [weather, trails, writing]
        var samples: [(String, String, String, Column, String)] = [
            ("Build the forecast card", "claude", "Build a five-day forecast card with an accessible color palette.", .running, weather.id),
            ("Map the trailheads", "codex", "Map the trailheads and nearby train stations.", .running, trails.id),
            ("Fix drag targets", "codex", "Fix the draggable forecast tiles and test keyboard controls.", .needsMe, weather.id),
            ("Compare walking routes", "claude", "Compare three walks for distance, train access and steep sections.", .ready, trails.id),
            ("Check forecast tests", "claude", "Check the forecast tests for missing-data cases.", .dealtWith, weather.id),
            ("Polish release notes", "codex", "Make the release notes shorter and clearer.", .ready, writing.id),
            ("Check station access", "codex", "Check step-free access at each station.", .dealtWith, trails.id),
            ("Package the preview", "codex", "Package the forecast preview for a friend to try.", .todo, weather.id),
            ("Plan a Sunday walk", "claude", "Prepare a short route with a good lunch stop.", .todo, trails.id)
        ]
        if ["stacks", "focus"].contains(mode) {
            samples += [
                ("Test compact layouts", "codex", "Test the forecast at small window sizes.", .running, weather.id),
                ("Review the preview build", "codex", "Try the preview build on a clean Mac.", .ready, weather.id),
                ("Improve keyboard access", "claude", "Check keyboard navigation and focus indicators.", .ready, weather.id),
                ("Review weather edge cases", "codex", "Review the weather fixtures for missing edge cases.", .ready, weather.id),
                ("Check train times", "codex", "Check the return trains for all three routes.", .ready, trails.id),
                ("Finish sample forecasts", "codex", "Check all sample forecast values.", .dealtWith, weather.id)
            ]
        }
        if mode == "parking" {
            let originals = samples
            samples += (1...4).flatMap { round in
                originals.map { ("\($0.0) · round \(round)", $0.1, $0.2, $0.3, $0.4) }
            }
        }
        for (index, s) in samples.enumerated() {
            let now = now - Double(index * 400)
            let r = RequestItem(id: "request-\(index)", text: s.2, time: now)
            let requests = index == 5 ? [
                RequestItem(id: "draft-notes", text: "Draft release notes for Pocket weather. Keep the tone calm and practical.", time: now - 7200),
                RequestItem(id: "trim-notes", text: "Lead with what changed. Remove the feature-by-feature tour.", time: now - 3600),
                r
            ] : [r]
            let reports = ["Compare walking routes": "Compared three walks. River Loop has the easiest train access; Ridge Path has one steep climb.",
                           "Polish release notes": "Shortened the introduction and explained the first release in three clear bullets.",
                           "Review the preview build": "Preview opens on a clean Mac. The first-launch instructions need a final read.",
                           "Improve keyboard access": "Added keyboard navigation and focus indicators. Screen-reader testing is still pending.",
                           "Review weather edge cases": "Found two missing cases: overnight frost and an unavailable forecast. Added fixtures for both.",
                           "Check train times": "Checked the return trains. River Loop has departures every 30 minutes.",
                           "Fix drag targets": "Needs your permission to run the keyboard interaction tests."]
            let report = reports[s.0] ?? ""
            let card = Conversation(id: "demo-\(index)", provider: s.1, nativeID: "demo", title: s.0, folder: "", updated: now, requests: requests, state: s.3 == .dealtWith || s.3 == .todo ? .ready : s.3, reason: s.3 == .needsMe ? "Permission needed" : "", response: report, eventID: "event", eventTime: now, url: "")
            state.cards.append(card)
            var d = Disposition(); d.projectID = s.4
            if mode == "parking" { d.parked = true }
            if priority, [1, 2, 5, 6, 7, 10].contains(index) { d.priority = true }
            if s.3 == .dealtWith { d.acknowledgedRevision = card.revision }
            if s.3 == .todo {
                d.manualColumn = .todo; d.manualRevision = card.revision; d.todoRequestID = r.id
                if s.4 == weather.id { d.todoNote = "Ask a friend to try the preview without instructions." }
            }
            state.dispositions[card.id] = d
            for request in requests {
                state.summaries[card.id + ":" + request.id] = Summary(text: request.text, inputHash: BoardStore.hash(request.text))
            }
            if !report.isEmpty {
                state.summaries[card.reportSummaryKey] = Summary(text: report, inputHash: BoardStore.hash(report), styleVersion: SummaryStyle.version)
            }
        }
        if mode == "outage" {
            for i in state.cards.indices where state.cards[i].provider == "codex" {
                state.cards[i].observationIssue = "History database busy"
            }
        }
        return state
    }
}

struct DemoCredentials: CredentialStorage {
    struct Disabled: LocalizedError {
        var errorDescription: String? { "Cloud services are disabled in demo mode." }
    }
    func status() async -> CredentialStatus { .missing }
    func load() async throws -> String { throw Disabled() }
    func save(_ value: String) async throws { throw Disabled() }
    func delete() async throws { }
}
