import Foundation
import KanbananaCore
import Darwin

package struct ReaderConfiguration: Sendable {
    package var executable: URL
    package var script: URL
    package var days: Int
    package var trackedIDs: [String]
    package var privacy: PrivacyOptions
    package init(executable: URL, script: URL, days: Int, trackedIDs: [String], privacy: PrivacyOptions) {
        self.executable = executable
        self.script = script
        self.days = days
        self.trackedIDs = trackedIDs
        self.privacy = privacy
    }
    package func arguments(for provider: ProviderID, historyID: String? = nil, before: String? = nil) -> [String] {
        var arguments = ["-I", "-B", "-u", script.path, "--provider", provider.rawValue,
                         "--days", String(days), "--parent-pid", String(ProcessInfo.processInfo.processIdentifier)]
        if let historyID {
            arguments += ["--history-id", historyID]
            if let before { arguments += ["--before-request", before] }
        } else {
            arguments += ["--watch"]
            arguments += trackedIDs.filter { $0.hasPrefix(provider.rawValue + ":") }.sorted().flatMap { ["--tracked-id", $0] }
        }
        if let home = privacy.codexHome { arguments += ["--codex-home", home] }
        if let home = privacy.claudeHome { arguments += ["--claude-home", home] }
        return arguments
    }
    package static func installed(days: Int, trackedIDs: [String], privacy: PrivacyOptions) throws -> Self {
        let resources = Bundle.main.resourceURL
        let candidates = [resources?.appendingPathComponent("reader.py"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/reader.py")]
        guard let script = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw ReaderFailure.missing }
        let python = resources?.appendingPathComponent("Python/bin/python3")
        let bundled = python.flatMap { FileManager.default.isExecutableFile(atPath: $0.path) ? $0 : nil }
        return Self(executable: bundled ?? URL(fileURLWithPath: "/usr/bin/python3"), script: script,
                    days: days, trackedIDs: trackedIDs, privacy: privacy)
    }
}

package protocol ReaderConnection: Sendable {
    var output: AsyncThrowingStream<Data, Error> { get }
    func stop() async
}

/// A narrow Foundation boundary. Launch/cancel state is lock-protected; the pipe is
/// read on a dedicated queue (never on Swift's cooperative executor or the UI).
/// The completion group is left only after waitUntilExit has reaped the child.
package final class ProcessReaderConnection: ReaderConnection, @unchecked Sendable {
    package let output: AsyncThrowingStream<Data, Error>
    private let process: Process
    private let lock = NSLock()
    private let finished = DispatchGroup()
    private var cancelled = false

    package init(executable: URL, arguments: [String]) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        self.process = process
        let (output, continuation) = AsyncThrowingStream<Data, Error>.makeStream(bufferingPolicy: .bufferingOldest(32))
        self.output = output
        finished.enter()
        continuation.onTermination = { [weak self] _ in self?.cancel() }
        DispatchQueue(label: "kanbanana.reader.pipe", qos: .utility).async { [self] in
            defer {
                try? pipe.fileHandleForReading.close()
                try? pipe.fileHandleForWriting.close()
                finished.leave()
            }
            do {
                try lock.withLock {
                    guard !cancelled else { throw CancellationError() }
                    try process.run()
                }
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    if case .dropped = continuation.yield(data) {
                        cancel()
                        process.waitUntilExit()
                        continuation.finish(throwing: ReaderFailure.oversized)
                        return
                    }
                }
                process.waitUntilExit()
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
    }

    private func cancel() {
        lock.withLock {
            cancelled = true
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [self] in
            lock.withLock {
                if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            }
        }
    }
    package func stop() async {
        cancel()
        await withCheckedContinuation { continuation in
            finished.notify(queue: .global(qos: .utility)) { continuation.resume() }
        }
    }
}
