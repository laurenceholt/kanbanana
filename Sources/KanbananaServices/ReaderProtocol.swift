import Foundation
import KanbananaCore

package enum ReaderFailure: Error, LocalizedError, Sendable {
    case protocolVersion, malformed, oversized, stopped, missing
    package var errorDescription: String? {
        switch self {
        case .protocolVersion: "The session reader uses an unsupported protocol. Rebuild the app."
        case .malformed: "The session reader returned an invalid observation."
        case .oversized: "A session-reader message exceeded the size limit."
        case .stopped: "The session reader stopped."
        case .missing: "The session reader is missing. Rebuild the app bundle."
        }
    }
}

/// The IPC schema deliberately does not serialize the board's durable model.
package struct ReaderFrame: Decodable, Sendable {
    let protocolVersion: Int
    let provider: ProviderID
    private let cards: [ObservedCard]
    let health: ProviderHealth
    let inventoryComplete: Bool
    let knownIDs: [String]
    let scannedAt: Double

    package func snapshot(expected: ProviderID) throws -> ProviderSnapshot {
        guard protocolVersion == 1 else { throw ReaderFailure.protocolVersion }
        guard provider == expected, scannedAt.isFinite,
              Set(cards.map(\.id)).count == cards.count,
              knownIDs.allSatisfy({ $0.hasPrefix(provider.rawValue + ":") }) else { throw ReaderFailure.malformed }
        return ProviderSnapshot(provider: provider, cards: try cards.map { try $0.conversation(provider: provider) },
            health: health, inventoryComplete: inventoryComplete, knownIDs: Set(knownIDs),
            scannedAt: scannedAt, completeHistory: false)
    }
}

private enum ObservedState: String, Decodable, Sendable {
    case running, needsMe, ready, unknown
    var column: Column {
        switch self { case .running: .running; case .needsMe: .needsMe; case .ready: .ready; case .unknown: .unknown }
    }
}

private struct ObservedCard: Decodable, Sendable {
    var id: String
    var nativeID: String
    var title: String
    var folder: String
    var updated: Double
    var requests: [RequestItem]
    var state: ObservedState
    var reason: String
    var eventID: String
    var eventTime: Double
    var url: String
    var observationIssue: String?

    func conversation(provider: ProviderID) throws -> Conversation {
        guard id == provider.rawValue + ":" + nativeID, !nativeID.isEmpty,
              updated.isFinite, eventTime.isFinite,
              requests.allSatisfy({ $0.time.isFinite }),
              Set(requests.map(\.id)).count == requests.count else { throw ReaderFailure.malformed }
        return Conversation(id: id, provider: provider.rawValue, nativeID: nativeID, title: title,
            folder: folder, updated: updated, requests: requests, state: state.column, reason: reason,
            eventID: eventID, eventTime: eventTime, url: url, observationIssue: observationIssue)
    }
}

package struct HistoryPage: Decodable, Sendable {
    package let protocolVersion: Int
    package let cardID: String
    package let requests: [RequestItem]
    package let hasMore: Bool
    package init(protocolVersion: Int = 1, cardID: String, requests: [RequestItem], hasMore: Bool) {
        self.protocolVersion = protocolVersion
        self.cardID = cardID
        self.requests = requests
        self.hasMore = hasMore
    }
}

/// Bound each newline-delimited message, including a worker that never sends a newline.
package struct ReaderFramer: Sendable {
    private var buffer = Data()
    package let maximumBytes: Int
    package init(maximumBytes: Int = 8 * 1024 * 1024) { self.maximumBytes = maximumBytes }
    package mutating func append(_ chunk: Data) throws -> [Data] {
        var result: [Data] = []
        // Process segments so a chunk containing many small frames is accepted.
        var start = chunk.startIndex
        while start < chunk.endIndex {
            let end = chunk[start...].firstIndex(of: 10) ?? chunk.endIndex
            guard buffer.count + chunk.distance(from: start, to: end) <= maximumBytes else { throw ReaderFailure.oversized }
            buffer.append(chunk[start..<end])
            if end < chunk.endIndex {
                if !buffer.isEmpty { result.append(buffer) }
                buffer = Data()
                start = chunk.index(after: end)
            } else { break }
        }
        return result
    }
    package func finish() throws { if !buffer.isEmpty { throw ReaderFailure.malformed } }
}
