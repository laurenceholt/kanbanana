import Foundation

/// Keep source order for requests with equal timestamps. Live deltas append;
/// pages prepend older requests without duplicating already observed messages.
package enum RequestHistory {
    package static func merging(_ current: [RequestItem], _ incoming: [RequestItem], older: Bool = false) -> [RequestItem] {
        let updates = Dictionary(incoming.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let existing = Set(current.map(\.id))
        let fresh = incoming.filter { !existing.contains($0.id) }
        let refreshed = current.map { updates[$0.id] ?? $0 }
        let combined: [RequestItem]
        if older, let anchor = current.firstIndex(where: { updates[$0.id] != nil }) {
            combined = Array(refreshed[..<anchor]) + incoming
                + refreshed[anchor...].filter { updates[$0.id] == nil }
        } else { combined = older ? fresh + refreshed : refreshed + fresh }
        return combined.enumerated().sorted {
            $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time
        }.map(\.element)
    }
}
