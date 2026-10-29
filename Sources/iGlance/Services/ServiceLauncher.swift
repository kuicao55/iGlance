import Foundation

struct ServiceLaunchOutcome {
    let manifest: ServiceManifest
}

enum ServiceLaunchError: LocalizedError {
    case emptyCommand
    case failedToStart(String)
    case exited(status: Int32, stderr: String)
    case manifestMissing(stderr: String)
    case invalidManifest(String, stderr: String)
    case timedOut(seconds: TimeInterval, stderr: String)

    var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return "The start command is empty."
        case .failedToStart(let detail):
            return "The start command could not be launched: \(detail)"
        case .exited(let status, let stderr):
            return Self.message("The start command exited with status \(status) before printing a manifest.", stderr: stderr)
        case .manifestMissing(let stderr):
            return Self.message("The start command finished without printing an IGLANCE_SERVICE_MANIFEST line.", stderr: stderr)
        case .invalidManifest(let detail, let stderr):
            return Self.message("The service manifest is invalid: \(detail)", stderr: stderr)
        case .timedOut(let seconds, let stderr):
            return Self.message("No IGLANCE_SERVICE_MANIFEST appeared within \(Int(seconds)) seconds.", stderr: stderr)
        }
    }

    private static func message(_ headline: String, stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return headline }
        return "\(headline)\n\n\(String(trimmed.suffix(800)))"
    }
}

/// Runs the user-approved start command with `/bin/zsh -lc` and waits for the
/// service manifest on stdout. The command is intentionally kept alive after
/// a successful handshake: it may be the service process itself.
final class ServiceLauncher {
    private let lock = NSLock()
    // A launched command may hand its stdout pipe to a daemon child that keeps
    // running after the shell exits. Keep the read end open (and draining)
    // until both streams reach EOF, otherwise the service could get SIGPIPE
    // the next time it writes a log line.
    private var retainedProcesses: [UUID: Process] = [:]
    // A very fast command can close both streams before `launch` has a chance
    // to retain it. Remember those tokens so the late retain is a no-op.
    private var releasedTokens: Set<UUID> = []

    /// Blocking. Call from a background task.
    func launch(
        bindingID: UUID,
        command: String,
        timeout: TimeInterval = 20
    ) throws -> ServiceLaunchOutcome {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceLaunchError.emptyCommand }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", trimmed]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let launchToken = UUID()
        let state = LaunchState()
        state.onStreamsClosed = { [weak self] in
            self?.release(launchToken: launchToken)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                state.markStdoutClosed()
            } else {
                state.appendStdout(data)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                state.markStderrClosed()
            } else {
                state.appendStderr(data)
            }
        }

        process.terminationHandler = { finished in
            state.markExit(status: finished.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw ServiceLaunchError.failedToStart(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(max(1, timeout))
        while true {
            let snapshot = state.snapshot()
            if snapshot.manifest != nil { break }
            if snapshot.exitStatus != nil && snapshot.stdoutClosed && snapshot.stderrClosed { break }
            if Date() >= deadline { break }
            _ = state.semaphore.wait(timeout: .now() + 0.05)
        }

        state.flushStdout()
        let snapshot = state.snapshot()

        if let manifest = snapshot.manifest {
            retain(process, token: launchToken)
            return ServiceLaunchOutcome(manifest: manifest)
        }

        if process.isRunning {
            // The handshake never completed. Avoid leaving an invisible
            // process behind; the start command is required to be idempotent.
            process.terminate()
        }

        if let status = snapshot.exitStatus {
            if status != 0 {
                throw ServiceLaunchError.exited(status: status, stderr: snapshot.stderr)
            }
            if let parseError = snapshot.parseError {
                throw ServiceLaunchError.invalidManifest(parseError, stderr: snapshot.stderr)
            }
            throw ServiceLaunchError.manifestMissing(stderr: snapshot.stderr)
        }

        if let parseError = snapshot.parseError {
            throw ServiceLaunchError.invalidManifest(parseError, stderr: snapshot.stderr)
        }
        throw ServiceLaunchError.timedOut(seconds: timeout, stderr: snapshot.stderr)
    }

    // MARK: - Process retention

    private func retain(_ process: Process, token: UUID) {
        lock.lock()
        if releasedTokens.remove(token) != nil {
            lock.unlock()
            return
        }
        retainedProcesses[token] = process
        lock.unlock()
    }

    private func release(launchToken: UUID) {
        lock.lock()
        if retainedProcesses.removeValue(forKey: launchToken) == nil {
            releasedTokens.insert(launchToken)
        }
        lock.unlock()
    }
}

// MARK: - Stream state

private final class LaunchState {
    struct Snapshot {
        let manifest: ServiceManifest?
        let exitStatus: Int32?
        let stdoutClosed: Bool
        let stderrClosed: Bool
        let parseError: String?
        let stderr: String
    }

    let semaphore = DispatchSemaphore(value: 0)
    var onStreamsClosed: (() -> Void)?

    private let lock = NSLock()
    private var accumulator = ServiceLineAccumulator()
    private var manifest: ServiceManifest?
    private var parseError: String?
    private var exitStatus: Int32?
    private var stdoutClosed = false
    private var stderrClosed = false
    private var stderrBuffer = Data()
    private var discardStdout = false
    private var notifiedStreamsClosed = false

    func appendStdout(_ data: Data) {
        var foundManifest = false

        lock.lock()
        if discardStdout {
            lock.unlock()
            return
        }

        for line in accumulator.append(data) {
            guard ServiceManifestParser.isManifestLine(line) else { continue }
            do {
                manifest = try ServiceManifestParser.parse(line: line)
                foundManifest = true
                break
            } catch {
                parseError = error.localizedDescription
            }
        }

        if manifest != nil {
            discardStdout = true
        }
        lock.unlock()

        if foundManifest {
            semaphore.signal()
        }
    }

    func flushStdout() {
        var foundManifest = false

        lock.lock()
        if !discardStdout, let line = accumulator.flush(), ServiceManifestParser.isManifestLine(line) {
            do {
                manifest = try ServiceManifestParser.parse(line: line)
                foundManifest = true
                discardStdout = true
            } catch {
                parseError = error.localizedDescription
            }
        }
        lock.unlock()

        if foundManifest {
            semaphore.signal()
        }
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderrBuffer.append(data)
        if stderrBuffer.count > 16_384 {
            stderrBuffer = Data(stderrBuffer.suffix(16_384))
        }
        lock.unlock()
    }

    func markStdoutClosed() {
        markStreamClosed(stdout: true)
    }

    func markStderrClosed() {
        markStreamClosed(stdout: false)
    }

    private func markStreamClosed(stdout: Bool) {
        var notify = false
        lock.lock()
        if stdout {
            stdoutClosed = true
        } else {
            stderrClosed = true
        }
        if stdoutClosed && stderrClosed && !notifiedStreamsClosed {
            notifiedStreamsClosed = true
            notify = true
        }
        lock.unlock()

        semaphore.signal()
        if notify {
            onStreamsClosed?()
        }
    }

    func markExit(status: Int32) {
        lock.lock()
        exitStatus = status
        lock.unlock()
        semaphore.signal()
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            manifest: manifest,
            exitStatus: exitStatus,
            stdoutClosed: stdoutClosed,
            stderrClosed: stderrClosed,
            parseError: parseError,
            stderr: String(decoding: stderrBuffer, as: UTF8.self)
        )
    }
}
