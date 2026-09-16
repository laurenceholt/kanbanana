import Foundation

package enum Column: String, Codable, CaseIterable, Sendable {
    case todo, running, needsMe, ready, dealtWith, unknown
    package var title: String { switch self { case .todo: "To do"; case .running: "Running"; case .needsMe: "Needs me"; case .ready: "Ready to check"; case .dealtWith: "Dealt with"; case .unknown: "Status unavailable" } }
    package var symbol: String { switch self { case .todo: "square.dashed"; case .running: "circle.dotted"; case .needsMe: "hand.raised.fill"; case .ready: "checkmark.circle"; case .dealtWith: "checkmark.circle.fill"; case .unknown: "questionmark.circle" } }
    package static let board: [Column] = [.todo, .running, .needsMe, .ready, .dealtWith]
}
package struct RequestItem: Codable, Sendable, Identifiable, Equatable {
    package init(id: String, text: String, time: Double) {
        self.id = id
        self.text = text
        self.time = time
    }

    package var id: String
    package var text: String
    package var time: Double
}
package struct Conversation: Codable, Sendable, Identifiable, Equatable {
    package init(id: String, provider: String, nativeID: String, title: String, folder: String, updated: Double, requests: [RequestItem], state: Column, reason: String, response: String = "", eventID: String, eventTime: Double, url: String, observationIssue: String? = nil) {
        self.id = id
        self.provider = provider
        self.nativeID = nativeID
        self.title = title
        self.folder = folder
        self.updated = updated
        self.requests = requests
        self.state = state
        self.reason = reason
        self.response = response
        self.eventID = eventID
        self.eventTime = eventTime
        self.url = url
        self.observationIssue = observationIssue
    }

    package var id: String
    package var provider: String
    package var nativeID: String
    package var title: String
    package var folder: String
    package var updated: Double
    package var requests: [RequestItem]
    package var state: Column
    package var reason: String
    package var response: String
    package var eventID: String
    package var eventTime: Double
    package var url: String
    // A failed observation is separate from the last observed task state.
    package var observationIssue: String? = nil
    package var providerName: String { provider == "claude" ? "Claude" : "Codex" }
    package var navigationURL: URL? {
        // Desktop's local IDs use the continue endpoint. /code/<id> accepts
        // cloud session IDs only. Resolve at click time to repair cached cards too.
        if provider == "claude", nativeID.hasPrefix("local_") {
            guard nativeID.range(of: "^local_[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil else { return nil }
            var link = URLComponents()
            link.scheme = "claude"
            link.host = "code"
            link.path = "/continue"
            link.queryItems = [URLQueryItem(name: "session", value: nativeID)]
            return link.url
        }
        guard let link = URL(string: url), ["claude", "codex"].contains(provider), link.scheme == provider else { return nil }
        return link
    }
    package var revision: String { "\(eventID)|\(requests.last?.id ?? "")|\(eventTime)" }
}
package struct Project: Codable, Sendable, Identifiable, Equatable {
    package init(id: String = UUID().uuidString, name: String, note: String = "", folders: [String] = [], colorIndex: Int? = nil, symbolIndex: Int? = nil) {
        self.id = id
        self.name = name
        self.note = note
        self.folders = folders
        self.colorIndex = colorIndex
        self.symbolIndex = symbolIndex
    }

    package var id = UUID().uuidString
    package var name: String
    package var note = ""
    package var folders: [String] = []
    package var colorIndex: Int?
    package var symbolIndex: Int?
}
package struct Disposition: Codable, Sendable, Equatable {
    package init(projectID: String? = nil, assignmentLocked: Bool = false, parked: Bool = false, parkedManually: Bool = false, restoredAt: Double = 0, acknowledgedRevision: String? = nil, manualColumn: Column? = nil, manualRevision: String? = nil, todoRequestID: String? = nil, todoNote: String? = nil, priority: Bool? = nil) {
        self.projectID = projectID
        self.assignmentLocked = assignmentLocked
        self.parked = parked
        self.parkedManually = parkedManually
        self.restoredAt = restoredAt
        self.acknowledgedRevision = acknowledgedRevision
        self.manualColumn = manualColumn
        self.manualRevision = manualRevision
        self.todoRequestID = todoRequestID
        self.todoNote = todoNote
        self.priority = priority
    }

    package var projectID: String?
    package var assignmentLocked = false
    package var parked = false
    package var parkedManually = false
    package var restoredAt: Double = 0
    package var acknowledgedRevision: String?
    package var manualColumn: Column?
    package var manualRevision: String?
    // Optional fields keep existing saved boards decodable. A reminder follows
    // the last request, not execution events that can keep arriving afterward.
    package var todoRequestID: String?
    package var todoNote: String?
    // Optional so existing boards decode without a migration. Nil means off.
    package var priority: Bool?
}

package enum CardOrder {
    package static func sorted(_ cards: [Conversation], dispositions: [String: Disposition]) -> [Conversation] {
        cards.sorted {
            let lhs = dispositions[$0.id]?.priority == true, rhs = dispositions[$1.id]?.priority == true
            if lhs != rhs { return lhs }
            if $0.updated != $1.updated { return $0.updated > $1.updated }
            return $0.id < $1.id
        }
    }
}
package struct Summary: Codable, Sendable, Equatable {
    package init(text: String, inputHash: String, styleVersion: Int? = nil) {
        self.text = text
        self.inputHash = inputHash
        self.styleVersion = styleVersion
    }

    package var text: String
    package var inputHash: String
    package var styleVersion: Int? = nil
}
package struct SavedState: Codable, Sendable, Equatable {
    package init() {}
    package var version = 1
    package var projects: [Project] = []
    package var dispositions: [String: Disposition] = [:]
    package var summaries: [String: Summary] = [:]
    package var cards: [Conversation] = []
    package var model = "gpt-5.4-mini"
    package var aiEnabled = false
    package var privacy: PrivacyOptions?
    package var summaryUsage: SummaryUsage?
    package var onboardingComplete: Bool?
}

// Pure lifecycle reducer. Manual acknowledgement is tied to source evidence,
// never just to the current wall clock or a recurring scan.
package enum Lifecycle {
    package static func reconcile(_ old: Conversation?, _ new: Conversation, _ saved: Disposition, now: Double, healthy: Bool) -> Disposition {
        var d = saved
        let fresh = old.map { $0.revision != new.revision && new.eventTime >= $0.eventTime } ?? false
        if fresh {
            let nextRequest = new.requests.last.map { $0.id != d.todoRequestID && $0.time >= (old?.requests.last?.time ?? 0) } ?? false
            if d.manualColumn != .todo || nextRequest {
                d.acknowledgedRevision = nil
                d.manualColumn = nil
                d.manualRevision = nil
                d.todoRequestID = nil
            }
            d.parked = false
            d.parkedManually = false
        }
        if d.manualColumn != .todo && healthy && new.state != .unknown && new.state != .running && now - max(new.updated, d.restoredAt) >= 7 * 86400 {
            d.parked = true
        }
        return d
    }
    package static func column(_ card: Conversation, _ d: Disposition) -> Column {
        if d.manualColumn == .todo { return .todo }
        if d.acknowledgedRevision == card.revision { return .dealtWith }
        if d.manualRevision == card.revision, let column = d.manualColumn { return column }
        if card.observationIssue != nil && card.state == .running { return .unknown }
        if card.state == .unknown { return .unknown }
        // Source observations can never create a personal reminder.
        return card.state == .todo ? .unknown : card.state
    }
}
