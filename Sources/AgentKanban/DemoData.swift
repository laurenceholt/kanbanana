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
        let math = Project(name: "Math interactives", note: "Build a set of fraction models.", colorIndex: 0, symbolIndex: 0)
        let boats = Project(name: "Weekend atlas", colorIndex: 1, symbolIndex: 6)
        let writing = Project(name: "Writing", colorIndex: 0, symbolIndex: 1)
        state.projects = [math, boats, writing]
        var samples: [(String, String, String, Column, String)] = [
            ("Build fraction model", "claude", "Apply the new framework to the fractions interactive.", .running, math.id),
            ("Plan a weekend route", "codex", "Collect marina and appointment details for the shortlist.", .running, boats.id),
            ("Fix dragging", "codex", "Fix the drag target labels and check touch behavior.", .needsMe, math.id),
            ("Compare shortlisted boats", "claude", "Collect ferry routes and walking trail details.", .ready, boats.id),
            ("Update evaluations", "claude", "Apply the revised rubric to the latest interactive.", .dealtWith, math.id),
            ("Polish article", "codex", "Revise the opening and simplify the final paragraph.", .ready, writing.id),
            ("Confirm marina map", "codex", "Check the stand numbers for our appointments.", .dealtWith, boats.id),
            ("Package the demo", "codex", "Build the installer for the interactive builder.", .todo, math.id),
            ("Plan boat visits", "claude", "Prepare a shortlist of boats to visit.", .todo, boats.id)
        ]
        if ["stacks", "focus"].contains(mode) {
            samples += [
                ("Test fractions on touch screens", "codex", "Check pointer and touch interactions.", .running, math.id),
                ("Review the builder installer", "codex", "Try the installer on a clean Mac.", .ready, math.id),
                ("Apply accessibility updates", "claude", "Apply the latest keyboard navigation rules.", .ready, math.id),
                ("Review the new rubric", "codex", "Review the evaluations and suggest missing cases.", .ready, math.id),
                ("Check Weekend atlas appointments", "codex", "Verify the appointment times with the shortlist.", .ready, boats.id),
                ("Finish fraction examples", "codex", "Check the final example values.", .dealtWith, math.id)
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
            let card = Conversation(id: "demo-\(index)", provider: s.1, nativeID: "demo", title: s.0, folder: "", updated: now, requests: [r], state: s.3 == .dealtWith || s.3 == .todo ? .ready : s.3, reason: s.3 == .needsMe ? "Permission needed" : "", response: "", eventID: "event", eventTime: now, url: "")
            state.cards.append(card)
            var d = Disposition(); d.projectID = s.4
            if mode == "parking" { d.parked = true }
            if priority, [1, 2, 5, 6, 7, 10].contains(index) { d.priority = true }
            if s.3 == .dealtWith { d.acknowledgedRevision = card.revision }
            if s.3 == .todo {
                d.manualColumn = .todo; d.manualRevision = card.revision; d.todoRequestID = r.id
                if s.4 == math.id { d.todoNote = "Try the installer on a writer’s Mac." }
            }
            state.dispositions[card.id] = d
            state.summaries[card.id + ":" + r.id] = Summary(text: r.text, inputHash: BoardStore.hash(r.text))
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
