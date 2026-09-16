import Foundation

enum Column: String, Codable, CaseIterable {
    case todo, running, needsMe, ready, dealtWith, unknown
    var title: String { switch self { case .todo: "To do"; case .running: "Running"; case .needsMe: "Needs me"; case .ready: "Ready to check"; case .dealtWith: "Dealt with"; case .unknown: "Status unavailable" } }
    var symbol: String { switch self { case .todo: "square.dashed"; case .running: "circle.dotted"; case .needsMe: "hand.raised.fill"; case .ready: "checkmark.circle"; case .dealtWith: "checkmark.circle.fill"; case .unknown: "questionmark.circle" } }
    static let board: [Column] = [.todo, .running, .needsMe, .ready, .dealtWith]
}
struct RequestItem: Codable, Identifiable, Equatable {
    var id: String
    var text: String
    var time: Double
}
struct Conversation: Codable, Identifiable, Equatable {
    var id: String
    var provider: String
    var nativeID: String
    var title: String
    var folder: String
    var updated: Double
    var requests: [RequestItem]
    var state: Column
    var reason: String
    var response: String
    var eventID: String
    var eventTime: Double
    var url: String
    // A failed observation is separate from the last observed task state.
    var observationIssue: String? = nil
    var providerName: String { provider == "claude" ? "Claude" : "Codex" }
    var navigationURL: URL? {
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
    var revision: String { "\(eventID)|\(requests.last?.id ?? "")|\(eventTime)" }
}
struct Snapshot: Decodable {
    var cards: [Conversation]
    var health: [String: String]
    var scannedAt: Double
}
struct Project: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var note = ""
    var folders: [String] = []
    var colorIndex: Int?
    var symbolIndex: Int?
}
struct Disposition: Codable, Equatable {
    var projectID: String?
    var assignmentLocked = false
    var parked = false
    var parkedManually = false
    var restoredAt: Double = 0
    var acknowledgedRevision: String?
    var manualColumn: Column?
    var manualRevision: String?
    // Optional fields keep existing saved boards decodable. A reminder follows
    // the last request, not execution events that can keep arriving afterward.
    var todoRequestID: String?
    var todoNote: String?
    // Optional so existing boards decode without a migration. Nil means off.
    var priority: Bool?
}

enum CardOrder {
    static func sorted(_ cards: [Conversation], dispositions: [String: Disposition]) -> [Conversation] {
        cards.sorted {
            let lhs = dispositions[$0.id]?.priority == true, rhs = dispositions[$1.id]?.priority == true
            if lhs != rhs { return lhs }
            if $0.updated != $1.updated { return $0.updated > $1.updated }
            return $0.id < $1.id
        }
    }
}
struct Summary: Codable, Equatable {
    var text: String
    var inputHash: String
    var styleVersion: Int? = nil
}
struct SavedState: Codable, Equatable {
    var version = 1
    var projects: [Project] = []
    var dispositions: [String: Disposition] = [:]
    var summaries: [String: Summary] = [:]
    var cards: [Conversation] = []
    var model = "gpt-5.4-mini"
    var aiEnabled = false
    var privacy: PrivacyOptions?
    var summaryUsage: SummaryUsage?
    var onboardingComplete: Bool?
}

// Pure lifecycle reducer. Manual acknowledgement is tied to source evidence,
// never just to the current wall clock or a recurring scan.
enum Lifecycle {
    static func reconcile(_ old: Conversation?, _ new: Conversation, _ saved: Disposition, now: Double, healthy: Bool) -> Disposition {
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
    static func column(_ card: Conversation, _ d: Disposition) -> Column {
        if d.manualColumn == .todo { return .todo }
        if d.acknowledgedRevision == card.revision { return .dealtWith }
        if d.manualRevision == card.revision, let column = d.manualColumn { return column }
        if card.observationIssue != nil && card.state == .running { return .unknown }
        if card.state == .unknown { return .unknown }
        // Source observations can never create a personal reminder.
        return card.state == .todo ? .unknown : card.state
    }
}
