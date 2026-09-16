import Foundation

/// Serialize file writes off the UI thread; final flushes use the same queue.
final class StatePersistence: @unchecked Sendable {
    private let queue = DispatchQueue(label: "AgentKanban.persistence", qos: .utility)
    static func decode(_ data: Data) throws -> SavedState {
        let state = try JSONDecoder().decode(SavedState.self, from: data)
        guard state.version == 1,
              Set(state.cards.map(\.id)).count == state.cards.count,
              Set(state.projects.map(\.id)).count == state.projects.count,
              (state.privacy?.dailySummaryLimit ?? 100) > 0,
              (state.privacy?.dailySummaryLimit ?? 100) <= 1000 else { throw CocoaError(.coderReadCorrupt) }
        return state
    }
    func writeAsync(_ state: SavedState, to url: URL, completion: @escaping @MainActor (Bool) -> Void) {
        queue.async {
            let succeeded = Self.write(state, to: url)
            Task { @MainActor in completion(succeeded) }
        }
    }
    func writeSync(_ state: SavedState, to url: URL) -> Bool { queue.sync { Self.write(state, to: url) } }
    func backupNow(_ url: URL) -> Bool { queue.sync { Self.backup(url, force: true) } }
    func restoreSync(_ state: SavedState, to url: URL) -> Bool {
        queue.sync {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    let previous = try Data(contentsOf: url)
                    if (try? Self.decode(previous)) != nil {
                        guard Self.backup(url, force: true) else { return false }
                    } else {
                        // Keep the original bytes for recovery even if the current board is corrupt.
                        let recovery = url.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)
                        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                        let original = recovery.appendingPathComponent("board-\(UUID().uuidString).json")
                        try previous.write(to: original, options: .atomic)
                        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: original.path)
                    }
                }
                return Self.write(state, to: url, backup: false)
            } catch { return false }
        }
    }
    static func export(_ state: SavedState, to url: URL) -> Bool { write(state, to: url, backup: false) }
    private static func backup(_ url: URL, force: Bool = false) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return true }
        do {
            let data = try Data(contentsOf: url)
            _ = try decode(data) // Never overwrite good backups with corrupt data.
            let folder = url.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]).filter { $0.lastPathComponent.range(of: #"^board-[0-9]+-[0-9A-Fa-f-]+\.json$"#, options: .regularExpression) != nil }.sorted { $0.lastPathComponent > $1.lastPathComponent }
            if !force, let latest = files.first, let time = try latest.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, Date().timeIntervalSince(time) < 3600 { return true }
            let name = "board-\(Int(Date().timeIntervalSince1970 * 1_000_000))-\(UUID().uuidString).json"
            let target = folder.appendingPathComponent(name)
            try data.write(to: target, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            for old in files.dropFirst(6) { try fm.removeItem(at: old) }
            return true
        } catch { return false }
    }
    private static func write(_ state: SavedState, to url: URL, backup shouldBackup: Bool = true) -> Bool {
        do {
            if shouldBackup && !backup(url) { return false }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            var durable = state
            for i in durable.cards.indices { durable.cards[i].response = "" }
            try encoder.encode(durable).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch { return false }
    }
}
