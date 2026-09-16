import Foundation

package enum BoardCommand: Sendable {
    case addProject(Project)
    case renameProject(String, String)
    case projectNote(String, String)
    case projectColor(String, Int)
    case projectSymbol(String, Int)
    case assign(String, String)
    case mark(String, Column)
    case park(String, Bool)
    case todoNote(String, String)
    case togglePriority(String)
}

package extension SavedState {
    /// Manual transitions always use the current card revision, not a captured view value.
    mutating func apply(_ command: BoardCommand, now: Double) {
        switch command {
        case .addProject(let project):
            if !projects.contains(where: { $0.id == project.id }) { projects.append(project) }
        case .renameProject(let id, let name):
            guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { projects[i].name = name }
        case .projectNote(let id, let note):
            if let i = projects.firstIndex(where: { $0.id == id }) { projects[i].note = note }
        case .projectColor(let id, let index):
            if let i = projects.firstIndex(where: { $0.id == id }), index >= 0 { projects[i].colorIndex = index }
        case .projectSymbol(let id, let index):
            if let i = projects.firstIndex(where: { $0.id == id }), index >= 0 { projects[i].symbolIndex = index }
        case .assign(let id, let project):
            guard cards.contains(where: { $0.id == id }), projects.contains(where: { $0.id == project }) else { return }
            var d = dispositions[id] ?? Disposition()
            d.projectID = project
            d.assignmentLocked = true
            dispositions[id] = d
        case .mark(let id, let column):
            guard column != .running && column != .unknown, let card = cards.first(where: { $0.id == id }) else { return }
            var d = dispositions[id] ?? Disposition()
            d.acknowledgedRevision = column == .dealtWith ? card.revision : nil
            d.manualColumn = column == .dealtWith ? nil : column
            d.manualRevision = column == .dealtWith ? nil : card.revision
            d.todoRequestID = column == .todo ? card.requests.last?.id ?? "" : nil
            if column == .todo { d.parked = false; d.parkedManually = false }
            dispositions[id] = d
        case .park(let id, let parked):
            guard cards.contains(where: { $0.id == id }) else { return }
            var d = dispositions[id] ?? Disposition()
            d.parked = parked
            d.parkedManually = parked
            if !parked { d.restoredAt = now }
            dispositions[id] = d
        case .todoNote(let id, let text):
            guard cards.contains(where: { $0.id == id }) else { return }
            let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
            var d = dispositions[id] ?? Disposition()
            d.todoNote = note.isEmpty ? nil : note
            dispositions[id] = d
        case .togglePriority(let id):
            guard cards.contains(where: { $0.id == id }) else { return }
            var d = dispositions[id] ?? Disposition()
            d.priority = d.priority == true ? nil : true
            dispositions[id] = d
        }
    }
}
