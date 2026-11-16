import Foundation

/// The result of one probe. Providers always synthesize the same status shape
/// as a manifest service, so `ServiceRuntime` and the card UI stay unchanged.
struct ServiceProbeResult: Equatable {
    let status: ServiceStatusResponse
    let memory: ServiceMemory?
}

protocol ServiceProvider {
    /// Probe the binding and return a synthesized status response.
    func status(for binding: ServiceBinding, token: String?) async throws -> ServiceProbeResult

    /// Start the service. Returns a manifest when one was discovered (the
    /// `manifest` kind); otherwise the caller simply refreshes.
    func start(_ binding: ServiceBinding) async throws -> ServiceManifest?

    /// Perform a control action. Providers throw for actions they do not
    /// support.
    func perform(_ action: ServiceControlAction, for binding: ServiceBinding, token: String?) async throws
}

enum ServiceProviderError: LocalizedError, Equatable {
    case missingConfiguration(String)
    case unsupported(String)
    case commandFailed(command: String, status: Int32, stderr: String, timedOut: Bool)
    case probeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let detail):
            return detail
        case .unsupported(let detail):
            return detail
        case .commandFailed(let command, let status, let stderr, let timedOut):
            let headline = timedOut
                ? "The command timed out: \(command)"
                : "The command failed with status \(status): \(command)"
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !detail.isEmpty else { return headline }
            return "\(headline)\n\n\(String(detail.suffix(800)))"
        case .probeFailed(let detail):
            return detail
        }
    }
}

// MARK: - Shared command runner

/// Thin async wrapper around `ProcessRunner`.
///
/// Probing uses the executable-and-arguments form, so labels and patterns are
/// never interpreted as shell syntax. Only explicit user-approved commands go
/// through `runShell` / `launchShell`.
struct ServiceCommandRunner {
    private let runner: ProcessRunner

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 5) async -> ProcessRunner.Result {
        await Task.detached(priority: .utility) { [runner] in
            runner.run(executable, arguments: arguments, timeout: timeout)
        }.value
    }

    /// For user-approved commands only. Uses a login shell so Homebrew and
    /// user-provided tools are on PATH.
    func runShell(_ command: String, timeout: TimeInterval = 30) async -> ProcessRunner.Result {
        await Task.detached(priority: .userInitiated) { [runner] in
            runner.run("/bin/zsh", arguments: ["-lc", command], timeout: timeout)
        }.value
    }

    /// Starts a long-running command without killing it after a timeout.
    func launchShell(_ command: String) async -> ProcessRunner.Result {
        await Task.detached(priority: .userInitiated) { [runner] in
            runner.launchDetachedShell(command)
        }.value
    }
}

// MARK: - Manifest

/// The original `iGlance service.v1` provider. Wraps `ServiceClient` and
/// `ServiceLauncher` so existing bindings behave exactly as before.
final class ManifestProvider: ServiceProvider {
    private let client: ServiceClient
    private let launcher: ServiceLauncher

    init(client: ServiceClient = ServiceClient(), launcher: ServiceLauncher = ServiceLauncher()) {
        self.client = client
        self.launcher = launcher
    }

    func status(for binding: ServiceBinding, token: String?) async throws -> ServiceProbeResult {
        guard binding.baseURL != nil else {
            throw ServiceProviderError.missingConfiguration(
                "No base URL is known yet. Start the service once to read its manifest."
            )
        }

        let status = try await client.fetchStatus(binding: binding, token: token)
        var memory = status.memory
        if memory == nil, binding.memoryPath != nil {
            memory = try? await client.fetchMemory(binding: binding, token: token)
        }
        return ServiceProbeResult(status: status, memory: memory)
    }

    func start(_ binding: ServiceBinding) async throws -> ServiceManifest? {
        let command = binding.trimmedStartCommand
        guard !command.isEmpty else { throw ServiceLaunchError.emptyCommand }

        let launcher = self.launcher
        return try await Task.detached(priority: .userInitiated) {
            try launcher.launch(bindingID: binding.id, command: command).manifest
        }.value
    }

    func perform(_ action: ServiceControlAction, for binding: ServiceBinding, token: String?) async throws {
        try await client.perform(action, binding: binding, token: token)
    }
}

// MARK: - launchd

/// Observes a LaunchAgent or LaunchDaemon by label.
///
/// `launchctl print` is a human-facing format, not a stable API. Parsing is
/// deliberately defensive: anything missing degrades to "offline" instead of
/// throwing, and a missing job is a normal offline state.
final class LaunchdProvider: ServiceProvider {
    struct Job: Equatable {
        var state: String?
        var pid: Int?
        var lastExitStatus: Int?
        var runs: Int?

        var isRunning: Bool { state == "running" || (pid ?? 0) > 0 }
    }

    private let commands: ServiceCommandRunner
    private let inspector: ProcessInspector
    private let uid: uid_t

    init(
        runner: ProcessRunner = ProcessRunner(),
        inspector: ProcessInspector? = nil,
        uid: uid_t = getuid()
    ) {
        self.commands = ServiceCommandRunner(runner: runner)
        self.inspector = inspector ?? ProcessInspector(runner: runner)
        self.uid = uid
    }

    var guiDomain: String { "gui/\(uid)" }

    func status(for binding: ServiceBinding, token: String?) async throws -> ServiceProbeResult {
        guard let label = binding.trimmedLaunchdLabel else {
            throw ServiceProviderError.missingConfiguration("Add a launchd label for this service.")
        }

        switch await lookup(label: label, domain: guiDomain) {
        case .found(let job):
            return await response(for: job, binding: binding)
        case .failed(let detail):
            return ServiceProbeResult(
                status: ServiceStatusResponse(state: "offline", error: detail),
                memory: nil
            )
        case .missing:
            break
        }

        // LaunchDaemons live in the system domain. `launchctl print` can read
        // that domain without root, but controlling it needs root.
        switch await lookup(label: label, domain: "system") {
        case .found(let job):
            return await response(for: job, binding: binding)
        case .failed(let detail):
            return ServiceProbeResult(
                status: ServiceStatusResponse(state: "offline", error: detail),
                memory: nil
            )
        case .missing:
            return ServiceProbeResult(
                status: ServiceStatusResponse(
                    state: "offline",
                    error: "Launchd job '\(label)' is not loaded in \(guiDomain) or system."
                ),
                memory: nil
            )
        }
    }

    func start(_ binding: ServiceBinding) async throws -> ServiceManifest? {
        guard !binding.readOnly else {
            throw ServiceProviderError.unsupported("This launchd binding is read-only. Disable Read-only in Edit Service to control it.")
        }
        guard let label = binding.trimmedLaunchdLabel else {
            throw ServiceProviderError.missingConfiguration("Add a launchd label for this service.")
        }

        guard let domain = await domain(for: label) else {
            throw ServiceProviderError.probeFailed(
                "Launchd job '\(label)' is not loaded. Load its plist with launchctl bootstrap first."
            )
        }
        guard domain == guiDomain else {
            throw ServiceProviderError.unsupported(
                "LaunchDaemons in the system domain can only be controlled as root. This binding is observation-only."
            )
        }

        let result = await commands.run("/bin/launchctl", ["kickstart", "\(guiDomain)/\(label)"])
        guard result.terminationStatus == 0 || Self.looksAlreadyRunning(result) else {
            throw Self.commandError("launchctl kickstart", result)
        }
        return nil
    }

    func perform(_ action: ServiceControlAction, for binding: ServiceBinding, token: String?) async throws {
        guard action == .stop else {
            throw ServiceProviderError.unsupported("Launchd services support Start and Stop only.")
        }
        guard !binding.readOnly else {
            throw ServiceProviderError.unsupported("This launchd binding is read-only. Disable Read-only in Edit Service to control it.")
        }
        guard let label = binding.trimmedLaunchdLabel else {
            throw ServiceProviderError.missingConfiguration("Add a launchd label for this service.")
        }

        guard let domain = await domain(for: label) else {
            return // Already unloaded — that is the state Stop asks for.
        }
        guard domain == guiDomain else {
            throw ServiceProviderError.unsupported(
                "LaunchDaemons in the system domain can only be controlled as root. This binding is observation-only."
            )
        }

        // bootout unloads the job; it is the only reliable stop while KeepAlive
        // is in play. A job that is already unloaded counts as stopped.
        let result = await commands.run("/bin/launchctl", ["bootout", "\(guiDomain)/\(label)"])
        guard result.terminationStatus == 0 || Self.looksAlreadyStopped(result) else {
            throw Self.commandError("launchctl bootout", result)
        }
    }

    // MARK: Labels

    /// Non-Apple labels currently loaded in the user's gui domain, for the
    /// editor's "Choose Loaded Job" menu.
    func loadedLabels() async -> [String] {
        let result = await commands.run("/bin/launchctl", ["list"])
        guard result.terminationStatus == 0 else { return [] }
        return Self.parseListLabels(result.stdout)
    }

    // MARK: Probing

    private enum Lookup {
        case found(Job)
        case missing
        case failed(String)
    }

    private func lookup(label: String, domain: String) async -> Lookup {
        let result = await commands.run("/bin/launchctl", ["print", "\(domain)/\(label)"])
        if result.terminationStatus == 0 {
            guard let job = Self.parsePrint(result.stdout) else {
                return .failed("Could not read the launchctl output for '\(domain)/\(label)'.")
            }
            return .found(job)
        }

        let output = (result.stdout + result.stderr).lowercased()
        if result.terminationStatus == 113 || output.contains("could not find service") {
            return .missing
        }
        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = detail.isEmpty
            ? "launchctl print failed with status \(result.terminationStatus)."
            : detail
        return .failed(message)
    }

    /// Which domain actually holds the job. Defaults to gui so the error
    /// message is useful when the label is simply wrong.
    private func domain(for label: String) async -> String? {
        if case .found = await lookup(label: label, domain: guiDomain) { return guiDomain }
        if case .found = await lookup(label: label, domain: "system") { return "system" }
        return nil
    }

    private func response(for job: Job, binding: ServiceBinding) async -> ServiceProbeResult {
        guard let pid = job.pid, pid > 0 else {
            var detail: String?
            if let exit = job.lastExitStatus, exit != 0 {
                detail = "Launchd job is loaded but not running (last exit \(exit))."
            }
            return ServiceProbeResult(
                status: ServiceStatusResponse(state: "offline", error: detail),
                memory: nil
            )
        }

        let sample = await inspector.sample(rootPIDs: [pid], includeDescendants: true)
        let memory = Self.memory(from: sample, label: binding.name)
        let uptime = sample.uptimeSec

        return ServiceProbeResult(
            status: ServiceStatusResponse(
                state: "running",
                pid: pid,
                startedAt: uptime.map { Date().addingTimeInterval(-$0) },
                uptimeSec: uptime,
                memory: memory
            ),
            memory: memory
        )
    }

    private static func memory(from sample: ProcessInspector.Sample, label: String) -> ServiceMemory {
        guard !sample.pids.isEmpty else {
            return ServiceMemory(available: false, source: "ps", error: "The process is no longer running.")
        }
        return ServiceMemory(
            available: true,
            source: "ps-rss",
            observedAt: Date(),
            totalRssBytes: sample.rssBytes,
            totalProcesses: sample.pids.count,
            groups: [
                ServiceMemoryGroup(
                    id: "service",
                    label: label,
                    rssBytes: sample.rssBytes,
                    processes: sample.pids.count,
                    pids: sample.pids
                )
            ],
            error: nil
        )
    }

    // MARK: Parsing

    static func parsePrint(_ output: String) -> Job? {
        let state = value(named: "state", in: output)
        let pid = value(named: "pid", in: output).flatMap(Int.init)
        let runs = value(named: "runs", in: output).flatMap(Int.init)
        let lastExit = value(named: "last exit code", in: output).flatMap(Int.init)

        // A job that is not loaded produces no output at all; an empty parse
        // means the format changed, so keep the job as loaded/unknown rather
        // than inventing a state.
        if state == nil && pid == nil && lastExit == nil && runs == nil {
            return nil
        }
        return Job(state: state, pid: pid, lastExitStatus: lastExit, runs: runs)
    }

    static func parseListLabels(_ output: String) -> [String] {
        var labels: [String] = []
        for line in output.split(whereSeparator: \.isNewline).dropFirst() {
            let raw = String(line)
            let columns = raw.split(separator: "\t", omittingEmptySubsequences: false)
            let label: String
            if columns.count >= 3 {
                label = String(columns[2]).trimmingCharacters(in: .whitespaces)
            } else {
                let parts = raw.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 3 else { continue }
                label = String(parts[2])
            }
            guard !label.isEmpty, !label.hasPrefix("com.apple.") else { continue }
            labels.append(label)
        }
        return labels.sorted()
    }

    private static func value(named name: String, in output: String) -> String? {
        let prefix = name + " = "
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) else { continue }
            let value = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func looksAlreadyRunning(_ result: ProcessRunner.Result) -> Bool {
        let output = (result.stdout + result.stderr).lowercased()
        return output.contains("already running") || output.contains("already loaded")
    }

    private static func looksAlreadyStopped(_ result: ProcessRunner.Result) -> Bool {
        let output = (result.stdout + result.stderr).lowercased()
        return output.contains("could not find service")
            || output.contains("no such process")
            || output.contains("not currently loaded")
    }

    private static func commandError(_ command: String, _ result: ProcessRunner.Result) -> ServiceProviderError {
        .commandFailed(
            command: command,
            status: result.terminationStatus,
            stderr: result.stderr,
            timedOut: result.timedOut
        )
    }
}

// MARK: - Processes

/// Finds and measures a process group by `pgrep -f` pattern or PID file.
final class ProcessProvider: ServiceProvider {
    private let commands: ServiceCommandRunner
    private let inspector: ProcessInspector

    init(runner: ProcessRunner = ProcessRunner(), inspector: ProcessInspector? = nil) {
        self.commands = ServiceCommandRunner(runner: runner)
        self.inspector = inspector ?? ProcessInspector(runner: runner)
    }

    func status(for binding: ServiceBinding, token: String?) async throws -> ServiceProbeResult {
        let roots = try await rootPIDs(for: binding)
        guard !roots.isEmpty else {
            var detail: String?
            if let pidFile = binding.trimmedPIDFile, binding.trimmedProcessPattern == nil {
                detail = "PID file \(pidFile) was not found or does not contain a PID."
            }
            return ServiceProbeResult(
                status: ServiceStatusResponse(state: "offline", error: detail),
                memory: nil
            )
        }

        let sample = await inspector.sample(rootPIDs: roots, includeDescendants: true)
        guard !sample.pids.isEmpty else {
            return ServiceProbeResult(
                status: ServiceStatusResponse(
                    state: "offline",
                    error: "The matched process exited before it could be measured."
                ),
                memory: nil
            )
        }

        let memory = Self.memory(from: sample, label: binding.name)
        let uptime = sample.uptimeSec
        return ServiceProbeResult(
            status: ServiceStatusResponse(
                state: "running",
                pid: sample.pids.first ?? roots.first,
                startedAt: uptime.map { Date().addingTimeInterval(-$0) },
                uptimeSec: uptime,
                memory: memory
            ),
            memory: memory
        )
    }

    func start(_ binding: ServiceBinding) async throws -> ServiceManifest? {
        guard !binding.readOnly else {
            throw ServiceProviderError.unsupported("This process binding is read-only.")
        }
        let command = binding.trimmedStartCommand
        guard !command.isEmpty else {
            throw ServiceProviderError.missingConfiguration("Add a start command or turn on Read-only.")
        }
        try await startControl(command)
        return nil
    }

    func perform(_ action: ServiceControlAction, for binding: ServiceBinding, token: String?) async throws {
        guard action == .stop else {
            throw ServiceProviderError.unsupported("Process services support Start and Stop only.")
        }
        guard !binding.readOnly else {
            throw ServiceProviderError.unsupported("This process binding is read-only.")
        }
        guard let command = binding.trimmedStopCommand else {
            throw ServiceProviderError.missingConfiguration("Add a stop command or turn on Read-only.")
        }
        try await stopControl(command)
    }

    // MARK: Helpers

    private func rootPIDs(for binding: ServiceBinding) async throws -> [Int] {
        if let pidFile = binding.trimmedPIDFile {
            if let pid = await inspector.pid(fromFile: pidFile) {
                return [pid]
            }
            // A configured PID file that is missing or empty is an offline
            // state, not a configuration error. Fall back to the pattern when
            // one is also configured.
            if binding.trimmedProcessPattern == nil {
                return []
            }
        }
        if let pattern = binding.trimmedProcessPattern {
            return try await inspector.pids(matching: pattern)
        }
        throw ServiceProviderError.missingConfiguration("Add a pgrep pattern or a PID file.")
    }

    private func startControl(_ command: String) async throws {
        let result = await commands.launchShell(command)
        guard result.terminationStatus == 0 else {
            throw ServiceProviderError.commandFailed(
                command: "start: \(command)",
                status: result.terminationStatus,
                stderr: result.stderr,
                timedOut: false
            )
        }
    }

    private func stopControl(_ command: String) async throws {
        let result = await commands.runShell(command, timeout: 30)
        guard result.terminationStatus == 0 else {
            throw ServiceProviderError.commandFailed(
                command: "stop: \(command)",
                status: result.terminationStatus,
                stderr: result.stderr,
                timedOut: result.timedOut
            )
        }
    }

    private static func memory(from sample: ProcessInspector.Sample, label: String) -> ServiceMemory {
        ServiceMemory(
            available: true,
            source: "ps-rss",
            observedAt: Date(),
            totalRssBytes: sample.rssBytes,
            totalProcesses: sample.pids.count,
            groups: [
                ServiceMemoryGroup(
                    id: "service",
                    label: label,
                    rssBytes: sample.rssBytes,
                    processes: sample.pids.count,
                    pids: sample.pids
                )
            ],
            error: nil
        )
    }
}

// MARK: - Command

/// A service controlled entirely by the user's own commands.
///
/// The status command may print nothing (exit 0 = running) or print a JSON
/// status object in the same shape as `ServiceStatusResponse`.
final class CommandProvider: ServiceProvider {
    private let commands: ServiceCommandRunner

    init(runner: ProcessRunner = ProcessRunner()) {
        self.commands = ServiceCommandRunner(runner: runner)
    }

    func status(for binding: ServiceBinding, token: String?) async throws -> ServiceProbeResult {
        guard let command = binding.trimmedStatusCommand else {
            throw ServiceProviderError.missingConfiguration("Add a status command for this service.")
        }

        let result = await commands.runShell(command, timeout: 10)
        if result.timedOut {
            throw ServiceProviderError.commandFailed(
                command: command, status: result.terminationStatus, stderr: result.stderr, timedOut: true
            )
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if stdout.hasPrefix("{"),
           let data = stdout.data(using: .utf8),
           let decoded = try? ServiceJSON.decoder.decode(ServiceStatusResponse.self, from: data) {
            let state = decoded.state ?? (result.terminationStatus == 0 ? "running" : "offline")
            let status = ServiceStatusResponse(
                schema: decoded.schema,
                ok: decoded.ok,
                service: decoded.service,
                state: state,
                paused: decoded.paused,
                stopping: decoded.stopping,
                pid: decoded.pid,
                startedAt: decoded.startedAt,
                uptimeSec: decoded.uptimeSec,
                urls: decoded.urls,
                auth: decoded.auth,
                memory: decoded.memory,
                controls: decoded.controls,
                error: decoded.error
            )
            return ServiceProbeResult(status: status, memory: decoded.memory)
        }

        let running = result.terminationStatus == 0
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let error: String? = running
            ? nil
            : (stderr.isEmpty ? "Status command exited with \(result.terminationStatus)." : String(stderr.suffix(800)))
        return ServiceProbeResult(
            status: ServiceStatusResponse(state: running ? "running" : "offline", error: error),
            memory: nil
        )
    }

    func start(_ binding: ServiceBinding) async throws -> ServiceManifest? {
        guard !binding.readOnly else {
            throw ServiceProviderError.unsupported("This command binding is read-only.")
        }
        let command = binding.trimmedStartCommand
        guard !command.isEmpty else {
            throw ServiceProviderError.missingConfiguration("Add a start command or turn on Read-only.")
        }
        try await startControl(command)
        return nil
    }

    func perform(_ action: ServiceControlAction, for binding: ServiceBinding, token: String?) async throws {
        guard action == .stop else {
            throw ServiceProviderError.unsupported("Command services support Start and Stop only.")
        }
        guard !binding.readOnly else {
            throw ServiceProviderError.unsupported("This command binding is read-only.")
        }
        guard let command = binding.trimmedStopCommand else {
            throw ServiceProviderError.missingConfiguration("Add a stop command or turn on Read-only.")
        }
        try await stopControl(command)
    }

    private func startControl(_ command: String) async throws {
        let result = await commands.launchShell(command)
        guard result.terminationStatus == 0 else {
            throw ServiceProviderError.commandFailed(
                command: "start: \(command)",
                status: result.terminationStatus,
                stderr: result.stderr,
                timedOut: false
            )
        }
    }

    private func stopControl(_ command: String) async throws {
        let result = await commands.runShell(command, timeout: 30)
        guard result.terminationStatus == 0 else {
            throw ServiceProviderError.commandFailed(
                command: "stop: \(command)",
                status: result.terminationStatus,
                stderr: result.stderr,
                timedOut: result.timedOut
            )
        }
    }
}

// MARK: - Process inspection

/// Collects PIDs, descendants, RSS, and elapsed time with `pgrep` and `ps`.
struct ProcessInspector {
    struct Sample: Equatable {
        let pids: [Int]
        let rssBytes: Int64
        let uptimeSec: Double?
    }

    private let commands: ServiceCommandRunner

    init(runner: ProcessRunner = ProcessRunner()) {
        self.commands = ServiceCommandRunner(runner: runner)
    }

    func pids(matching pattern: String) async throws -> [Int] {
        let result = await commands.run("/usr/bin/pgrep", ["-f", "--", pattern])
        switch result.terminationStatus {
        case 0:
            return Self.parseIntegerLines(result.stdout)
        case 1:
            return []
        default:
            throw ServiceProviderError.probeFailed(
                "pgrep failed with status \(result.terminationStatus): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }
    }

    func pid(fromFile path: String) async -> Int? {
        let expanded = (path as NSString).expandingTildeInPath
        guard let contents = try? String(contentsOfFile: expanded, encoding: .utf8) else {
            return nil
        }
        return Self.parsePIDFile(contents)
    }

    func descendants(of roots: [Int]) async -> [Int] {
        var seen = Set(roots)
        var queue = roots
        var result: [Int] = []
        var depth = 0

        while !queue.isEmpty, depth < 8 {
            var next: [Int] = []
            for pid in queue {
                let probe = await commands.run("/usr/bin/pgrep", ["-P", String(pid)])
                guard probe.terminationStatus == 0 else { continue }
                for child in Self.parseIntegerLines(probe.stdout) where !seen.contains(child) {
                    seen.insert(child)
                    result.append(child)
                    next.append(child)
                }
            }
            queue = next
            depth += 1
        }
        return result
    }

    func sample(rootPIDs: [Int], includeDescendants: Bool) async -> Sample {
        var pids = rootPIDs
        if includeDescendants {
            pids += await descendants(of: rootPIDs)
        }
        pids = Array(Set(pids)).sorted()
        guard !pids.isEmpty else { return Sample(pids: [], rssBytes: 0, uptimeSec: nil) }

        let result = await commands.run(
            "/bin/ps",
            ["-o", "pid=,rss=,etime=", "-p", pids.map(String.init).joined(separator: ",")]
        )
        let rows = Self.parsePSSample(result.stdout)
        let rss = rows.reduce(Int64(0)) { $0 + $1.rssBytes }
        let uptime = rows.compactMap(\.uptimeSec).max()
        return Sample(pids: rows.map(\.pid), rssBytes: rss, uptimeSec: uptime)
    }

    // MARK: Parsing

    static func parseIntegerLines(_ output: String) -> [Int] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            Int(line.trimmingCharacters(in: .whitespaces))
        }
    }

    static func parsePIDFile(_ contents: String) -> Int? {
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let pid = Int(trimmed), pid > 0 else { return nil }
            return pid
        }
        return nil
    }

    struct PSRow: Equatable {
        let pid: Int
        let rssBytes: Int64
        let uptimeSec: Double?
    }

    static func parsePSSample(_ output: String) -> [PSRow] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 3,
                  let pid = Int(parts[0]),
                  let rssKB = Int64(parts[1]) else {
                return nil
            }
            return PSRow(
                pid: pid,
                rssBytes: rssKB * 1024,
                uptimeSec: parseElapsed(String(parts[2]))
            )
        }
    }

    /// Parses `ps -o etime` values: `MM:SS`, `HH:MM:SS`, or `DD-HH:MM:SS`.
    static func parseElapsed(_ raw: String) -> Double? {
        var value = raw.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        var days = 0.0
        if let dash = value.firstIndex(of: "-") {
            guard let parsedDays = Double(value[value.startIndex..<dash]) else { return nil }
            days = parsedDays
            value = String(value[value.index(after: dash)...])
        }

        let components = value.split(separator: ":").compactMap { Double($0) }
        guard !components.isEmpty, components.count <= 3 else { return nil }

        let seconds: Double
        switch components.count {
        case 1: seconds = components[0]
        case 2: seconds = components[0] * 60 + components[1]
        default: seconds = components[0] * 3600 + components[1] * 60 + components[2]
        }

        return days * 86_400 + seconds
    }
}
