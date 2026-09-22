import Foundation

package enum ProviderID: String, Codable, CaseIterable, Sendable {
    case claude, codex
    package var title: String { self == .claude ? "Claude" : "Codex" }
}

/// Connection health is independent of the last task state and its event time.
package struct ProviderHealth: Codable, Equatable, Sendable {
    package enum Status: String, Codable, Sendable {
        case connected, partial, disabled, notInstalled, noSessions
        case accessDenied, unsupported, unavailable, stale
    }
    package var status: Status
    package var issue: String?
    package init(_ status: Status, issue: String? = nil) {
        self.status = status
        self.issue = issue
    }
    package var canObserve: Bool { status == .connected || status == .partial }
    package var message: String {
        let label: String = switch status {
        case .connected: "Connected"
        case .partial: "Some histories unavailable"
        case .disabled: "Disabled"
        case .notInstalled: "Not installed"
        case .noSessions: "No local sessions"
        case .accessDenied: "Access denied"
        case .unsupported: "Unsupported format"
        case .unavailable: "Unavailable"
        case .stale: "Updates paused"
        }
        return issue.map { label + " · " + $0 } ?? label
    }
}

package struct ProviderSnapshot: Sendable {
    package let provider: ProviderID
    package let cards: [Conversation]
    package let health: ProviderHealth
    /// Only a complete inventory may establish that a known card is absent.
    package let inventoryComplete: Bool
    package let knownIDs: Set<String>
    package let scannedAt: Double
    /// Incremental status messages carry only the most recent request.
    package let completeHistory: Bool

    package init(provider: ProviderID, cards: [Conversation], health: ProviderHealth,
                 inventoryComplete: Bool, knownIDs: Set<String>, scannedAt: Double,
                 completeHistory: Bool = true) {
        self.provider = provider
        self.cards = cards
        self.health = health
        self.inventoryComplete = inventoryComplete
        self.knownIDs = knownIDs
        self.scannedAt = scannedAt
        self.completeHistory = completeHistory
    }
}

package enum BoardReconciler {
    package static func apply(_ snapshot: ProviderSnapshot, to state: SavedState) -> SavedState {
        var next = state
        var byID = Dictionary(uniqueKeysWithValues: state.cards.map { ($0.id, $0) })
        for var card in snapshot.cards {
            let old = byID[card.id]
            // Metadata proves the conversation exists even if its history is unreadable.
            card.sourceMissing = nil
            if card.observationIssue != nil, let old {
                card.requests = old.requests
                card.eventID = old.eventID
                card.eventTime = old.eventTime
                card.state = old.state
                if old.sourceMissing != true { card.reason = old.reason }
                card.response = old.response
            } else if !snapshot.completeHistory, let old {
                card.requests = RequestHistory.merging(old.requests, card.requests)
            }
            // Keep only the bounded latest report, never a full response history.
            card.response = String(card.response.suffix(20000))
            var disposition = Lifecycle.reconcile(old, card, next.dispositions[card.id] ?? Disposition(),
                now: snapshot.scannedAt, healthy: snapshot.health.canObserve && card.observationIssue == nil)
            if disposition.projectID == nil {
                if let project = next.projects.first(where: {
                    card.folder.isEmpty ? $0.name == "Ungrouped" && $0.folders.isEmpty : $0.folders.contains(card.folder)
                }) {
                    disposition.projectID = project.id
                } else {
                    let project = Project(name: card.folder.isEmpty ? "Ungrouped" : URL(fileURLWithPath: card.folder).lastPathComponent,
                                          folders: card.folder.isEmpty ? [] : [card.folder])
                    next.projects.append(project)
                    disposition.projectID = project.id
                }
            }
            next.dispositions[card.id] = disposition
            byID[card.id] = card
        }
        let changedIDs = Set(snapshot.cards.map(\.id))
        for (id, var card) in byID where card.provider == snapshot.provider.rawValue {
            if !snapshot.health.canObserve {
                card.observationIssue = snapshot.health.issue ?? snapshot.health.message
            } else if snapshot.inventoryComplete && !snapshot.knownIDs.contains(id) {
                card.state = .unknown
                card.reason = "Conversation not found in source history"
                card.observationIssue = nil
                card.sourceMissing = true
                next.dispositions[id] = Lifecycle.reconcile(card, card, next.dispositions[id] ?? Disposition(),
                    now: snapshot.scannedAt, healthy: true)
            } else if !changedIDs.contains(id) {
                // A delta heartbeat can restore transport health without resending history.
                // Partial inventories cannot clear an individual read failure.
                if snapshot.health.status == .connected { card.observationIssue = nil }
                if snapshot.health.status == .partial && !snapshot.knownIDs.contains(id) {
                    card.observationIssue = snapshot.health.issue ?? "Some histories could not be read"
                }
                next.dispositions[id] = Lifecycle.reconcile(card, card, next.dispositions[id] ?? Disposition(),
                    now: snapshot.scannedAt, healthy: snapshot.health.status == .connected && card.observationIssue == nil)
            }
            byID[id] = card
        }
        next.cards = byID.values.sorted { $0.id < $1.id }
        return next
    }
}
